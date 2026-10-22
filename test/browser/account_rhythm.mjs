// Synthetic local account only; no live user data or real billing actions.
export default async function verifyAccountRhythm(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use isolated browser server')
  const results = []
  const scenarios = [
    ['dashboard', '/app/dashboard'], ['account', '/app/perfil'],
    ['personal', '/app/perfil/dados-pessoais'], ['access', '/users/edit'],
    ['subscription', '/app/perfil/assinaturas'], ['notifications', '/app/perfil/notificacoes'],
    ['instruments', '/app/playground?activity=percepcao&question_mode=melodic_dictation'],
    ['rhythm-simple', '/app/playground?activity=ritmica&level=1&meter_id=mixed&activity_mode=precision'],
    ['rhythm-advanced', '/app/playground?activity=ritmica&level=4&meter_id=mixed&activity_mode=precision']
  ]
  for (const [size, width, height] of [['desktop',1440,1000],['tablet',820,1180],['mobile',360,844]]) {
    await page.setViewportSize({width,height})
    for (const [name,path] of scenarios) {
      await page.goto(origin+path)
      if (name === 'instruments' || name.startsWith('rhythm-')) {
        if (!await page.locator('.playground-settings').evaluate(n=>n.open)) await page.locator('.playground-settings > summary').click()
      }
      for (const theme of ['light','dark']) {
        await page.locator('.theme-picker > summary').click()
        await page.getByRole('button',{name:theme === 'light'?'Claro':'Escuro',exact:true}).click()
        await page.locator('h1').click()
        await page.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));await Promise.all(document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{})));await new Promise(r=>requestAnimationFrame(r))})
        const measured=await page.evaluate(()=>{
          const box=n=>n?.getBoundingClientRect().width
          const settings=document.querySelector('.playground-settings'), stage=document.querySelector('.playground-stage__grid')
          return {overflow:document.documentElement.scrollWidth>innerWidth,translationMissing:document.body.innerText.toLowerCase().includes('translation missing'),
            settingsWidth:box(settings),stageWidth:box(stage),topProfile:!!document.querySelector('.app-topbar .profile-link'),
            instruments:document.querySelectorAll('.instrument-icon').length,accountSections:document.querySelectorAll('.account-links a').length}
        })
        if(measured.overflow||measured.translationMissing||measured.topProfile)throw Error(JSON.stringify({name,size,theme,measured}))
        if(measured.settingsWidth&&Math.abs(measured.settingsWidth-measured.stageWidth)>1)throw Error('Settings/stage width mismatch')
        if(name==='instruments'&&measured.instruments!==5)throw Error('Missing instrument icons')
        const screenshot=`output/playwright/account-rhythm/${name}-${size}-${theme}.png`
        await page.screenshot({path:screenshot,fullPage:true})
        results.push({name,size,theme,screenshot,...measured})
      }
    }
  }
  return results
}
