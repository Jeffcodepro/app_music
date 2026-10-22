// Synthetic authenticated account on the isolated browser server only.
export default async function verifyDashboardMeterMatrix(page, state='empty') {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Use the isolated browser server')
  const results=[]
  const settle=()=>page.evaluate(async()=>{await document.fonts.ready;await Promise.all(document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))})
  const scenarios=state==='empty'?[['dashboard-empty','/app/dashboard']]:[
    ['dashboard-active','/app/dashboard'],['dictation-settings','/app/playground?activity=percepcao&question_mode=melodic_dictation'],
    ['meter-simple','/app/playground?activity=ritmica&level=1&meter_id=2-4&activity_mode=pulse'],
    ['meter-compound','/app/playground?activity=ritmica&level=2&meter_id=6-8&activity_mode=subdivision'],
    ['meter-additive','/app/playground?activity=ritmica&level=4&meter_id=7-8-2-2-3&activity_mode=precision'],
    ['meter-dense','/app/playground?activity=ritmica&level=3&meter_id=12-4&activity_mode=precision']]
  for(const [size,width,height]of[['desktop',1440,1000],['tablet',820,1180],['mobile',360,844]]){
    await page.setViewportSize({width,height})
    for(const [name,path]of scenarios){
      await page.goto(origin+path)
      if(name==='dictation-settings'&&!await page.locator('.playground-settings').evaluate(n=>n.open))await page.locator('.playground-settings > summary').click()
      for(const theme of ['light','dark']){
        await page.locator('.theme-picker > summary').click();await page.getByRole('button',{name:theme==='light'?'Claro':'Escuro',exact:true}).click()
        await page.locator('h1').click();await page.evaluate(()=>scrollTo(0,0));await settle()
        const measurement=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,theme:document.documentElement.dataset.theme,
          scores:[...document.querySelectorAll('.rhythm-score-scroll')].map(n=>({width:n.clientWidth,scrollWidth:n.scrollWidth})),
          instrumentCards:document.querySelectorAll('.playground-select-card input[name=instrument]').length}))
        if(measurement.overflow)throw Error(`${name}/${size}/${theme} document overflow`)
        if(name==='dictation-settings'&&measurement.instrumentCards!==5)throw Error('Instrument cards mismatch')
        const screenshot=`output/playwright/dashboard-meters/${name}-${size}-${theme}.png`
        await page.screenshot({path:screenshot,fullPage:true});results.push({name,size,theme,screenshot,...measurement})
      }
    }
  }
  return results
}
