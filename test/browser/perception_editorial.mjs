// Supply correctAnswers read ONLY from this synthetic user's isolated assignments.
// Uses real playback and real POSTs; no answer key is inferred from the DOM.
export default async function verifyPerceptionEditorial(page, correctAnswers) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin) throw Error('Use the isolated server')
  const check=(condition,message)=>{if(!condition) throw Error(message)}
  const result={states:[],screenshots:[],answerPosts:0,renderedContrast:[]}
  const count=request=>{if(request.method()==='POST'&&request.url().includes('/app/playground'))result.answerPosts++}
  page.on('request',count)
  const ready=()=>page.waitForFunction(()=>{
    const c=window.__editorialPlayer
    return c&&!c.isPlaying&&c.playbackChannel().lastPlayedDigest===c.currentPlaybackDigest()
  })
  const bind=()=>page.evaluate(()=>{
    const el=document.querySelector('[data-controller~="interval-player"]')
    window.__editorialPlayer=window.Stimulus.getControllerForElementAndIdentifier(el,'interval-player')
  })
  const capture=async(name,width=390,height=844)=>{
    await page.setViewportSize({width,height})
    await page.locator('h1').click()
    await page.evaluate(async()=>{await document.fonts.ready;scrollTo(0,0);await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))})
    const path=`output/playwright/redesign03/states/${name}.png`
    await page.screenshot({path,fullPage:true});result.screenshots.push(path)
  }
  const measureContrast=async(state)=>{
    const measurements=await page.evaluate(()=>{
      const rgb=s=>(s.match(/[\d.]+/g)||[]).slice(0,3).map(Number)
      const luminance=c=>{const v=c.map(n=>n/255).map(n=>n<=.04045?n/12.92:((n+.055)/1.055)**2.4);return v[0]*.2126+v[1]*.7152+v[2]*.0722}
      const values=[],walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT)
      for(let node=walker.nextNode();node;node=walker.nextNode()) {
        const text=node.textContent.trim(),el=node.parentElement
        if(!text||!el||el.closest('script,style,[aria-hidden=true],[hidden]'))continue
        const rect=el.getBoundingClientRect(),style=getComputedStyle(el)
        if(!el.getClientRects().length||rect.bottom<0||style.visibility==='hidden')continue
        let bg=null
        for(let parent=el;parent;parent=parent.parentElement) {
          const c=getComputedStyle(parent).backgroundColor
          if(c!=='transparent'&&c!=='rgba(0, 0, 0, 0)'){bg=c;break}
        }
        if(!bg)continue
        const a=luminance(rgb(style.color)),b=luminance(rgb(bg))
        values.push({text:text.slice(0,70),foreground:style.color,background:bg,ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)})
      }
      return values
    })
    const failures=measurements.filter(m=>m.ratio<4.5)
    check(!failures.length,`Rendered text contrast: ${JSON.stringify(failures)}`)
    result.renderedContrast.push({state,count:measurements.length,minimum:Math.min(...measurements.map(m=>m.ratio)),measurements})
  }
  try {
    await page.goto(origin+'/app/playground?activity=percepcao')
    await page.waitForLoadState('networkidle')
    await page.getByRole('combobox',{name:'Tema da interface'}).selectOption('light')
    await bind()
    const id=await page.locator('[name=assignment_id]').first().inputValue()
    check(correctAnswers[id],'Missing isolated reference answer for current assignment')
    await page.locator('.perception-option').first().click()
    check(result.answerPosts===0,'Unheard audio must not submit an answer')
    check(await page.locator('[data-interval-player-target=hint]').isVisible(),'Missing listening instruction')
    result.states.push('before-listening: visible instruction; zero POSTs')
    await page.getByRole('button',{name:'Tocar intervalo',exact:true}).click()
    const pending=await page.locator('.playback-status').getAttribute('data-state')
    check(['loading','playing'].includes(pending),'Missing pending playback')
    await page.locator('.perception-option').first().click()
    check(result.answerPosts===0,'Playing audio must not submit')
    await capture('percepcao-reproduzindo-light-mobile')
    await ready()
    check(await page.locator('.playback-status').getAttribute('data-state')==='completed','Missing completed playback status')
    await capture('percepcao-escuta-concluida-light-mobile')
    const wrong=page.locator('.perception-options form').filter({has:page.locator(`input[name=selected_option_id]:not([value="${correctAnswers[id]}"])`)}).first()
    const oldToken=await wrong.locator('[name=attempt_token]').inputValue()
    await wrong.locator('button').click()
    await page.locator('.playground-feedback.is-incorrect').waitFor()
    check(await page.locator('.perception-option.is-last-answer').count()===1,'Server must identify the last selected answer')
    check(await page.locator('[name=assignment_id]').first().inputValue()===id,'Wrong answer changed assignment')
    check(await page.locator('[name=attempt_token]').first().inputValue()!==oldToken,'Retry token not renewed')
    await capture('percepcao-selecao-incorreta-light-desktop',1440,900)
    await capture('percepcao-selecao-incorreta-light-mobile')
    await measureContrast('incorrect-light')
    await page.getByRole('combobox',{name:'Tema da interface'}).selectOption('dark')
    await capture('percepcao-selecao-incorreta-dark-mobile')
    await bind()
    await page.getByRole('button',{name:'Repetir intervalo',exact:true}).click()
    await ready()
    const correct=page.locator('.perception-options form').filter({has:page.locator(`input[name=selected_option_id][value="${correctAnswers[id]}"]`)})
    await correct.locator('button').click()
    await page.locator('.playground-feedback.is-correct').waitFor()
    check(await page.locator('.perception-option[disabled]').count()===4,'Solved round must close all choices')
    check(await page.locator('.perception-option.is-last-answer .perception-option__meta').innerText()==='Sua resposta','Missing selected label')
    await capture('percepcao-selecao-correta-dark-desktop',1440,900)
    await capture('percepcao-selecao-correta-dark-mobile')
    await measureContrast('correct-dark')
    await page.getByRole('combobox',{name:'Tema da interface'}).selectOption('light')
    await capture('percepcao-selecao-correta-light-mobile')
    result.states.push('real wrong feedback; same assignment; renewed token; real correct retry; one selected choice; four closed choices')
    await page.goto(origin+'/app/dashboard')
    result.dashboard={attempts:await page.locator('[data-testid=attempt-count]').innerText(),xp:await page.locator('[data-testid=xp-total]').innerText(),rows:await page.locator('[data-testid=history-row]').count()}
    check(result.dashboard.attempts==='2'&&result.dashboard.xp==='20'&&result.dashboard.rows===2,'Wrong+correct must total two attempts and 20 XP')
    for(const mode of ['light','dark']) {
      await page.getByRole('combobox',{name:'Tema da interface'}).selectOption(mode)
      await capture(`dashboard-com-atividade-${mode}-desktop`,1440,900)
      await capture(`dashboard-com-atividade-${mode}-mobile`)
    }
    // Next round stops the previous playback, preserving the existing channel contract.
    await page.goto(origin+'/app/playground?activity=percepcao&refresh=1')
    await bind()
    await page.getByRole('button',{name:'Tocar intervalo',exact:true}).click()
    await page.waitForFunction(()=>window.__editorialPlayer.isPlaying&&window.__editorialPlayer.playbackChannel().activePlaybackHandles.length>0)
    await page.getByRole('link',{name:'Próximo intervalo',exact:true}).click()
    await page.waitForFunction(()=>!window.__editorialPlayer.element.isConnected)
    check(await page.evaluate(()=>window.__editorialPlayer.playbackChannel().activePlaybackHandles.length===0),'Playback survived next round')
    result.states.push('next round cancels the previous audio')
    await page.route('https://gleitz.github.io/**',route=>route.abort())
    try {
      await page.reload()
      await page.waitForLoadState('networkidle')
      await bind()
      await page.getByRole('button',{name:'Tocar intervalo',exact:true}).click()
      await ready()
      check(await page.evaluate(()=>window.__appMusicAudioDiagnostics.some(e=>e.engine==='synth')),'Blocked sample CDN must fall back to synth')
      result.states.push('sample CDN blocked: synthesizer completes playback')
      await page.evaluate(()=>{window.__editorialPlayer.playWithSynth=()=>{throw Error('simulated output failure')};window.__editorialPlayer.stop()})
      await page.getByRole('button',{name:'Tocar intervalo',exact:true}).click()
      await page.locator('[data-playback-error]').waitFor({state:'visible'})
      check(await page.locator('.playback-status').getAttribute('data-state')==='unavailable','Missing unavailable state')
      const postsBefore=result.answerPosts
      await page.locator('.perception-option').first().click()
      check(result.answerPosts===postsBefore,'Failed audio must not submit')
      await capture('percepcao-falha-neutra-dark-mobile')
      result.states.push('both engines fail: unavailable status, neutral message, zero extra POSTs')
    } finally { await page.unroute('https://gleitz.github.io/**') }
    check(result.answerPosts===2,'Only the two real responses may submit')
    return result
  } finally {page.off('request',count)}
}
