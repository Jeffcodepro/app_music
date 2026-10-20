export default async function verifyGrandstaffLayout(page) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Isolated test server required')
  const results=[]
  await page.setViewportSize({width:1440,height:1000})
  for(let count=0;count<20;count++){
    await page.goto(origin+'/app/playground?activity=percepcao&question_mode=melodic_dictation&level=4&instrument=flute&refresh=1')
    if(await page.locator('[data-melody-player-voice-count-value]').getAttribute('data-melody-player-voice-count-value')==='4')break
    if(count===19)throw Error('Missing four-voice candidate')
  }
  const variants=await page.locator('.voiced-score').evaluateAll(nodes=>nodes.map(n=>({staves:n.querySelectorAll('.voiced-staff').length,voices:n.querySelectorAll('.voiced-voice').length,viewBox:n.getAttribute('viewBox')})))
  if(variants.some(n=>n.staves!==2||n.voices!==4)||new Set(variants.map(n=>n.viewBox)).size!==1)throw Error('Incorrect grouped score')
  if(await page.locator('[data-melody-player-instrument-value]').getAttribute('data-melody-player-instrument-value')!=='piano')throw Error('Advanced dictation must use piano')
  for(const width of [1440,768,390]){
    await page.setViewportSize({width,height:1000})
    for(const theme of ['light','dark']){
      await page.locator('.theme-picker >summary').click();await page.getByRole('button',{name:theme==='light'?'Claro':'Escuro',exact:true}).click()
      await page.evaluate(async()=>{await document.fonts.ready;await Promise.all(document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{})))})
      const bounds=await page.locator('.voiced-score-scroll').first().evaluate(el=>{const button=el.querySelector('button').getBoundingClientRect(),svg=el.querySelector('svg').getBoundingClientRect();return{width:el.clientWidth,scrollWidth:el.scrollWidth,buttonWidth:button.width,svgWidth:svg.width,contained:svg.left>=button.left&&svg.right<=button.right,overflow:document.documentElement.scrollWidth>innerWidth}})
      if(bounds.overflow||!bounds.contained)throw Error('Clipped score or click target')
      const region=page.locator('.voiced-score-scroll').first()
      if(width===390){
        await region.focus();await page.keyboard.press('ArrowRight');await page.waitForFunction(()=>document.querySelector('.voiced-score-scroll').scrollLeft>0)
        await region.evaluate(el=>el.scrollLeft=el.scrollWidth)
        let posts=0;const listener=req=>{if(req.method()==='POST'&&new URL(req.url()).pathname==='/app/playground/answer')posts++}
        page.on('request',listener);try{await region.locator('svg ellipse').last().click();if(posts)throw Error('Unheard score submitted')}finally{page.off('request',listener)}
        await region.evaluate(el=>el.scrollLeft=0)
      }
      await page.screenshot({path:`output/playwright/grandstaff-refinement/four-voices-${theme}-${width}.png`,fullPage:true})
      results.push({viewportWidth:width,theme,...bounds})
    }
  }
  await page.goto(origin+'/app/playground?activity=percepcao&question_mode=melodic_dictation&level=3&instrument=flute')
  if(!await page.locator('.playground-settings').evaluate(el=>el.open))await page.locator('.playground-settings >summary').click()
  await page.locator('.playground-option-grid').screenshot({path:'output/playwright/grandstaff-refinement/original-instrument-icons.png'})
  if(await page.locator('.playground-select-card__icon img').count()!==5)throw Error('Original assets missing')
  const wind=await page.locator('.voiced-score').first().evaluate(el=>({staves:el.querySelectorAll('.voiced-staff').length,clefs:[...el.querySelectorAll('.voiced-staff')].map(n=>n.dataset.clef)}))
  if(wind.staves!==1||wind.clefs[0]!=='treble')throw Error('Wind duet must share a treble staff')
  await page.goto(origin+'/app/playground?activity=ritmica&level=3&meter_id=12-4&activity_mode=precision')
  const dense=page.locator('.rhythm-score-scroll').first();await dense.focus();await page.keyboard.press('ArrowRight')
  await page.waitForFunction(()=>document.querySelector('.rhythm-score-scroll').scrollLeft>0)
  if(await page.locator('.rhythm-options button svg').count()!==4)throw Error('Rhythm score is not directly selectable')
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Rhythm overflow')
  return{variants,screens:results,windDuet:wind,rhythmDirectSelectionAndKeyboard:true}
}
