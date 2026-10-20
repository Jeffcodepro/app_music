// Anonymous synthetic browser session on the guarded private server only.
export default async function verifyPublicUI(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use the isolated server')
  const check = (value, message) => { if (!value) throw Error(message) }
  const errors = [], requests = [], matrix = []
  const onError = error => errors.push(error.message)
  const onRequest = request => requests.push(request.url())
  page.on('pageerror', onError); page.on('request', onRequest)
  await page.addInitScript(() => {
    window.__uiLayoutShifts = []
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) if (!entry.hadRecentInput) window.__uiLayoutShifts.push({ value: entry.value, time: entry.startTime })
    }).observe({type:'layout-shift', buffered:true})
  })
  try {
    await page.goto(origin)
    check(page.url() === origin + '/', 'Use an anonymous synthetic browser context')
    const settle = () => page.evaluate(async () => { await document.fonts.ready; await Promise.all(document.getAnimations().map(a=>a.finished.catch(()=>{}))); scrollTo(0,0) })
    const sizes = [[360,640],[375,667],[390,844],[768,1024],[820,1180],[1024,768],[1366,768],[1440,900],[1920,1080]]
    for (const theme of ['light','dark']) {
      await page.getByRole('combobox',{name:'Tema da interface'}).selectOption(theme)
      for (const [width,height] of sizes) {
        await page.setViewportSize({width,height}); await settle()
        const metrics = await page.evaluate(() => ({theme:document.documentElement.dataset.theme,
          overflow:document.documentElement.scrollWidth>innerWidth, h1:document.querySelectorAll('h1').length,
          videos:document.querySelectorAll('video').length, nested:document.querySelectorAll('a button').length,
          dead:document.querySelectorAll('a[href="#"]').length,
          brokenAnchors:[...document.querySelectorAll('a[href^="#"]')].filter(a=>!document.getElementById(a.hash.slice(1))).map(a=>a.hash),
          headingFamily:getComputedStyle(document.querySelector('h1')).fontFamily,
          illustration:!!document.querySelector('.public-score svg[role=img]'),
          animations:document.getAnimations().length
        }))
        check(!metrics.overflow && metrics.h1===1 && !metrics.videos && !metrics.nested && !metrics.dead && !metrics.brokenAnchors.length && metrics.illustration,`Public structure ${width} ${theme}`)
        if(width<992) {
          const toggle=page.locator('button[aria-controls=public-menu]')
          const started=Date.now()
          await toggle.evaluate(e=>{window.__samePublicToggle=e})
          await toggle.click()
          check(await page.locator('#public-menu').getAttribute('aria-modal')==='true','Public drawer modal')
          check(await toggle.evaluate(e=>!e.closest('[inert]') && e===window.__samePublicToggle && e===document.activeElement),'Same accessible opening button')
          check(await page.evaluate(()=>document.body.style.overflow==='hidden'),'Public scroll lock')
          await page.keyboard.press('Shift+Tab')
          check(await page.locator('#public-menu a').last().evaluate(e=>e===document.activeElement),'Public focus wraps backwards')
          await page.keyboard.press('Tab')
          await toggle.click()
          check(await toggle.getAttribute('aria-expanded')==='false','Same button closes public drawer')
          metrics.openCloseMilliseconds=Date.now()-started
          await toggle.click(); await page.keyboard.press('Escape')
          check(await toggle.evaluate(e=>e===document.activeElement),'Public focus restored')
        }
        await page.screenshot({path:`output/playwright/uiux02-integral/after/landing-${theme}-${width}.png`,fullPage:true})
        matrix.push({width,height,...metrics})
      }
    }
    await page.setViewportSize({width:390,height:844})
    const toggle=page.locator('button[aria-controls=public-menu]')
    await toggle.click()
    await page.locator('.app-backdrop').click({position:{x:370,y:400}})
    check(await toggle.getAttribute('aria-expanded')==='false','Outside click public drawer')
    await toggle.click()
    await page.locator('#public-menu').getByRole('link',{name:'As práticas'}).click()
    await page.waitForURL('**/#praticas')
    check(page.url().endsWith('#praticas') && !await page.locator('[data-app-shell-target=workspace]').evaluate(e=>e.inert),'Anchor closes and unlocks public drawer')
    await page.locator('#duvidas summary').first().focus(); await page.keyboard.press('Enter')
    check(await page.locator('#duvidas details').first().getAttribute('open')!==null,'FAQ keyboard disclosure')
    await page.emulateMedia({reducedMotion:'reduce'})
    check(await page.evaluate(()=>document.getAnimations().length===0),'No public animations under reduced motion')
    await page.emulateMedia({reducedMotion:'no-preference'})
    await page.evaluate(()=>window.__publicTurboMarker='preserved')
    await page.getByRole('link',{name:'Já tenho conta',exact:true}).click()
    await page.waitForURL('**/users/sign_in')
    check(await page.evaluate(()=>window.__publicTurboMarker)==='preserved','Public to auth uses Turbo')
    check(await page.locator('html').getAttribute('data-theme')==='dark','Auth retains public theme')
    await page.goBack()
    check(!await page.locator('[data-app-shell-target=workspace]').evaluate(e=>e.inert),'Turbo back public is operable')
    await page.setViewportSize({width:1440,height:900}); await page.reload(); await settle()
    const performance = await page.evaluate(()=>({layoutShifts:window.__uiLayoutShifts,
      cls:window.__uiLayoutShifts.reduce((sum,e)=>sum+e.value,0),
      navigation:performance.getEntriesByType('navigation').map(e=>({responseStart:e.responseStart,domContentLoaded:e.domContentLoadedEventEnd,load:e.loadEventEnd})),
      resources:performance.getEntriesByType('resource').map(e=>({name:e.name,duration:e.duration,transferSize:e.transferSize})),
      fonts:[...document.fonts].filter(f=>f.status==='loaded').map(f=>f.family)
    }))
    check(!requests.some(url=>/tailwind|lucide|grainy-gradients|seamless_loop|design_system|scroll_video|Nunito|Work.Sans|JetBrains/i.test(url)),'No prototype dependency loaded')
    check(!errors.length,`Public runtime errors: ${errors.join('; ')}`)
    return {matrix,performance,externalRequests:[...new Set(requests.filter(url=>!url.startsWith(origin)))],errors,turbo:true,faqKeyboard:true}
  } finally { page.off('pageerror',onError); page.off('request',onRequest) }
}
