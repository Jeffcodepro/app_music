// refs comes from the synthetic user's assignments in the isolated database.
// It must never be obtained from a public correction endpoint or DOM metadata.
export default async function verifyVoicedDictationAudio(page, refs) {
  if(new URL(page.url()).origin!=='http://127.0.0.1:3001')throw Error('Use isolated browser server')
  const check=(ok,message)=>{if(!ok)throw Error(message)}
  const ready=()=>page.waitForFunction(()=>document.querySelector('.playback-status')?.dataset.state==='completed')
  const state=()=>page.locator('[data-controller~="melody-player"]').evaluate(el=>({
    id:el.dataset.melodyPlayerExerciseSignatureValue,events:JSON.parse(el.dataset.melodyPlayerEventsValue).length,voices:+el.dataset.melodyPlayerVoiceCountValue
  }))
  const initial=await state()
  check(refs[initial.id], 'Missing synthetic answer reference')
  await page.evaluate(()=>{
    const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="melody-player"]'),'melody-player')
    const proto=Object.getPrototypeOf(c)
    window.__voicedNotes=[];window.__voicedPlays=[]
    const sampled=proto.playVoicedSoundfont,synth=proto.scheduleTone,play=proto.play
    proto.playVoicedSoundfont=function(player,request){
      return sampled.call(this,{play:(pitch,time,options)=>{
        window.__voicedNotes.push({engine:'soundfont',id:this.exerciseSignatureValue,pitch,time,...options})
        return player.play(pitch,time,options)
      }},request)
    }
    proto.scheduleTone=function(frequency,time,duration,request,gain){
      window.__voicedNotes.push({engine:'synth',id:this.exerciseSignatureValue,frequency,time,duration,gain})
      return synth.call(this,frequency,time,duration,request,gain)
    }
    proto.play=function(...args){window.__voicedPlays.push(this.exerciseSignatureValue);return play.apply(this,args)}
  })
  const start=Date.now()
  await page.getByRole('button',{name:'Tocar ditado melódico',exact:true}).click()
  await ready()
  const first=await page.evaluate(()=>({notes:window.__voicedNotes,plays:window.__voicedPlays,diagnostics:window.__appMusicAudioDiagnostics}))
  check(first.notes.length===initial.events && first.plays.length===1, 'Initial phrase did not play exactly once')
  check(first.notes.filter(n=>n.time===first.notes[0].time).length===initial.voices, 'Voices did not start together')
  check(Date.now()-start>=6000, 'Readiness before full two-bar phrase')
  let posts=0;const listener=req=>{if(new URL(req.url()).pathname==='/app/playground/answer'&&req.method()==='POST')posts++}
  page.on('request',listener)
  try {
    await page.locator(`.melody-options input[name=selected_option_id][value="${refs[initial.id]}"]`).locator('..').locator('button').click()
    await page.locator('.playground-feedback.is-correct').waitFor()
    await page.getByRole('button',{name:'Repetir ditado melódico',exact:true}).click();await ready()
    check((await state()).id===initial.id,'Repeat advanced assignment')
    await page.getByRole('link',{name:'Próximo ditado e tocar',exact:true}).click()
    await page.waitForFunction(old=>document.querySelector('[data-melody-player-exercise-signature-value]')?.dataset.melodyPlayerExerciseSignatureValue!==old,initial.id)
    await ready()
    const next=await state()
    const played=await page.evaluate(id=>({notes:window.__voicedNotes.filter(n=>n.id===id),plays:window.__voicedPlays.filter(value=>value===id)}),next.id)
    check(played.notes.length===next.events&&played.plays.length===1,'Next phrase did not autoplay once')
    check(await page.locator('select[name=level]').inputValue()==='3','Next lost difficulty')
    // Real synth fallback in the browser, after simulated sample unavailability.
    await page.evaluate(()=>{const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="melody-player"]'),'melody-player');c.waitForSoundfontPlayer=async()=>null})
    await page.getByRole('button',{name:'Repetir ditado melódico',exact:true}).click();await ready()
    const fallback=await page.evaluate(id=>({notes:window.__voicedNotes.filter(n=>n.id===id&&n.engine==='synth'),diagnostic:window.__appMusicAudioDiagnostics.at(-1)}),next.id)
    check(fallback.notes.length===next.events&&fallback.notes.every(n=>Math.abs(n.gain-1/next.voices)<1e-8),'Synth missing voices or headroom')
    // Both engines failing must keep scoring neutral.
    await page.evaluate(()=>{const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="melody-player"]'),'melody-player');c.ensureAudioContext=async()=>{throw Error('Synthetic device failure')}})
    await page.getByRole('button',{name:'Repetir ditado melódico',exact:true}).click()
    await page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='unavailable')
    await page.locator('.melody-options button').first().click()
    check(posts===1,'Repeat or failed audio submitted an answer')
    return {initial,next,initialEngine:first.notes[0].engine,initialNotes:first.notes.length,initialReadyAfterFullPhrase:true,nextPlayedOnce:true,fallbackEngine:fallback.diagnostic.engine,fallbackNotes:fallback.notes.length,posts,failureNeutral:true}
  } finally {page.off('request',listener)}
}
