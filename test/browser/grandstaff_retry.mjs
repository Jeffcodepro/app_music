// Call only on the isolated synthetic account; answer is read from that DB.
export default async function verifyGrandstaffRetry(page, correctId) {
  if(new URL(page.url()).origin!=='http://127.0.0.1:3001')throw Error('Isolated server required')
  const check=(ok,message)=>{if(!ok)throw Error(message)}
  const ready=()=>page.waitForFunction(()=>document.querySelector('.playback-status')?.dataset.state==='completed')
  const state=()=>page.locator('[data-controller~="melody-player"]').evaluate(el=>({id:el.dataset.melodyPlayerExerciseSignatureValue,token:el.querySelector('[name=attempt_token]').value,ids:[...el.querySelectorAll('[name=selected_option_id]')].map(n=>n.value)}))
  const before=await state()
  let posts=0;const listener=req=>{if(new URL(req.url()).pathname==='/app/playground/answer'&&req.method()==='POST')posts++}
  page.on('request',listener)
  try{
    await page.evaluate(()=>{const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="melody-player"]'),'melody-player'),proto=Object.getPrototypeOf(c),play=proto.play;window.__retryPlays=[];proto.play=function(...args){window.__retryPlays.push(this.exerciseSignatureValue);return play.apply(this,args)}})
    await page.getByRole('button',{name:'Tocar ditado melódico',exact:true}).click();await ready()
    const wrong=before.ids.find(id=>id!==correctId)
    await page.locator(`.melody-options input[value="${wrong}"][name=selected_option_id]`).locator('..').locator('svg ellipse').first().click()
    await page.locator('.playground-feedback.is-incorrect').waitFor()
    const retry=await state()
    check(retry.id===before.id&&retry.token!==before.token&&JSON.stringify(retry.ids)===JSON.stringify(before.ids),'Wrong answer changed musical event or ordering')
    await page.locator(`.melody-options input[value="${correctId}"][name=selected_option_id]`).locator('..').locator('button').focus()
    await page.keyboard.press('Enter')
    await page.locator('.playground-feedback.is-correct').waitFor()
    check(posts===2&&await page.evaluate(()=>window.__retryPlays.length)===1,'Retry required or triggered new playback')
    await page.getByRole('link',{name:'Próximo ditado e tocar',exact:true}).click()
    await page.waitForFunction(old=>document.querySelector('[data-melody-player-exercise-signature-value]')?.dataset.melodyPlayerExerciseSignatureValue!==old,before.id)
    await ready()
    const next=await state()
    check(await page.evaluate(()=>window.__retryPlays.length)===2,'Next played more than once')
    await page.evaluate(()=>{const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="melody-player"]'),'melody-player');c.ensureAudioContext=async()=>{throw Error('Synthetic device failure')}})
    await page.getByRole('button',{name:'Repetir ditado melódico',exact:true}).click()
    await page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='unavailable')
    await page.locator('.melody-options button svg').first().click()
    check(posts===2,'Failed replay reused old readiness')
    return {before:before.id,next:next.id,posts,wrongThenCorrectWithoutReplay:true,orderPreserved:true,nextPlayedOnce:true,failedReplayNeutral:true}
  }finally{page.off('request',listener)}
}
