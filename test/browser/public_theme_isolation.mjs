export default async function verifyPublicThemeIsolation(page) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Isolated test server required')
  const context=await page.context().browser().newContext({viewport:{width:1440,height:1000},colorScheme:'dark'})
  await context.addInitScript(()=>localStorage.setItem('app_music_theme','dark'))
  const publicPage=await context.newPage(),results=[]
  try{
    await publicPage.goto(origin,{waitUntil:'domcontentloaded'})
    await publicPage.locator('#vantagens').waitFor()
    for(const width of [1440,768,390]){
      await publicPage.setViewportSize({width,height:1000})
      await publicPage.locator('.landing-evolution-copy').locator('..').scrollIntoViewIfNeeded()
      await publicPage.waitForFunction(()=>+getComputedStyle(document.querySelector('.landing-evolution-copy').parentElement).opacity>=.99)
      await publicPage.evaluate(async()=>{await document.fonts.ready;await Promise.all(document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))})
      const state=await publicPage.evaluate(()=>{
        const copy=document.querySelector('.landing-evolution-copy'),style=getComputedStyle(copy)
        return{theme:document.documentElement.dataset.theme,stored:localStorage.getItem('app_music_theme'),themeControls:document.querySelectorAll('.theme-control,.theme-picker').length,copyBackground:style.backgroundColor,copyBackdrop:style.backdropFilter,overflow:document.documentElement.scrollWidth>innerWidth}
      })
      if(state.theme!=='light'||state.stored!=='dark'||state.themeControls||state.overflow||state.copyBackground!=='rgba(0, 0, 0, 0)'||state.copyBackdrop!=='none')throw Error('Public theme regression '+JSON.stringify(state))
      await publicPage.locator('.landing-evolution-copy').screenshot({path:`output/playwright/grandstaff-refinement/landing-copy-${width}.png`})
      await publicPage.locator('.landing-evolution-copy').locator('..').screenshot({path:`output/playwright/grandstaff-refinement/landing-evolution-card-${width}.png`})
      await publicPage.screenshot({path:`output/playwright/grandstaff-refinement/landing-cards-${width}.png`})
      await publicPage.locator('.landing-nav').screenshot({path:`output/playwright/grandstaff-refinement/landing-navbar-${width}.png`})
      results.push({width,...state})
    }
    await publicPage.setViewportSize({width:1440,height:1000})
    await publicPage.locator('.landing-nav a').filter({hasText:'Login'}).click()
    await publicPage.locator('#user_email').fill('compact@example.test');await publicPage.locator('#user_password').fill('compact-local-test')
    await publicPage.getByRole('button',{name:'Entrar',exact:true}).click();await publicPage.waitForURL('**/app/dashboard')
    await publicPage.waitForFunction(()=>document.documentElement.dataset.theme==='dark')
    return{screens:results,authenticatedPreferenceRestored:true}
  }finally{await context.close()}
}
