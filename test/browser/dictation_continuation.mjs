// Run after real listening; references come only from the synthetic isolated DB.
export default async function verifyDictationContinuation(page, references) {
  if(new URL(page.url()).origin!=='http://127.0.0.1:3001')throw Error('Use isolated browser server')
  const initial=await page.locator('[data-melody-player-exercise-signature-value]').getAttribute('data-melody-player-exercise-signature-value')
  const answer=references[initial];if(!answer)throw Error('Missing synthetic reference')
  let posts=0,gets=0;const listener=request=>{const url=new URL(request.url());if(url.pathname==='/app/playground/answer'&&request.method()==='POST')posts++;if(url.pathname==='/app/playground'&&request.method()==='GET')gets++}
  page.on('request',listener)
  const ready=()=>page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='completed')
  try{
    await page.locator(`.melody-options input[name=selected_option_id][value="${answer}"]`).locator('..').locator('button').click()
    await page.locator('.playground-feedback.is-correct').waitFor()
    await page.getByRole('link',{name:'Próximo ditado e tocar',exact:true}).waitFor()
    await page.getByRole('button',{name:'Repetir ditado melódico',exact:true}).click();await ready()
    if(await page.locator('[data-melody-player-exercise-signature-value]').getAttribute('data-melody-player-exercise-signature-value')!==initial)throw Error('Repeat changed assignment')
    if(gets!==0)throw Error('Repeat navigated')
    await page.evaluate(()=>{
      const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="melody-player"]'),'melody-player')
      const proto=Object.getPrototypeOf(c);window.__continuationNotes=[];window.__continuationPlays=[]
      const sound=proto.scheduleBlockedSoundfontChord,synth=proto.scheduleBlockedSynthChord,play=proto.play
      proto.scheduleBlockedSoundfontChord=function(player,pitches,time,duration,request){window.__continuationNotes.push({engine:'soundfont',assignment:this.exerciseSignatureValue,pitches,time});return sound.call(this,player,pitches,time,duration,request)}
      proto.scheduleBlockedSynthChord=function(frequencies,time,duration,request){window.__continuationNotes.push({engine:'synth',assignment:this.exerciseSignatureValue,frequencies,time});return synth.call(this,frequencies,time,duration,request)}
      proto.play=function(...args){window.__continuationPlays.push(this.exerciseSignatureValue);return play.apply(this,args)}
    })
    await page.getByRole('link',{name:'Próximo ditado e tocar',exact:true}).click()
    await page.waitForFunction(old=>document.querySelector('[data-melody-player-exercise-signature-value]')?.dataset.melodyPlayerExerciseSignatureValue!==old,initial)
    await ready()
    const next=await page.locator('[data-melody-player-exercise-signature-value]').getAttribute('data-melody-player-exercise-signature-value')
    const first=await page.evaluate(()=>({notes:window.__continuationNotes,plays:window.__continuationPlays}))
    if(first.notes.length!==4||first.plays.length!==1||first.plays[0]!==next)throw Error('Next did not play exactly one new melody')
    await page.getByRole('button',{name:'Repetir ditado melódico',exact:true}).click();await ready()
    if(await page.evaluate(()=>window.__continuationNotes.length)!==8)throw Error('Repeat did not add one pass')
    if(posts!==1||gets!==1)throw Error('Unexpected submission or navigation')
    await page.screenshot({path:'output/playwright/dashboard-meters/dictation-next-after-correct.png',fullPage:true})
    await page.goto('http://127.0.0.1:3001/app/dashboard')
    const xp=await page.locator('[data-testid=xp-total]').innerText(),attempts=await page.locator('[data-testid=attempt-count]').innerText()
    if(xp!=='20'||attempts!=='1')throw Error('Next or repeat credited again')
    return{initial,next,posts,gets,repeatKeepsAssignment:true,autoPlayedOnce:true,repeatNotes:8,xp,attempts,...first}
  }finally{page.off('request',listener)}
}
