// Run with an authenticated synthetic student on the private test server.
// Browser context must support Playwright; no production account or database.
export default async function verifyStudyEditorial(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use the isolated server on port 3001')
  const check = (value, message) => { if (!value) throw Error(message) }
  const result = { matrix: [], interactions: [], contrast: [], errors: [] }
  const error = e => result.errors.push(e.message)
  page.on('pageerror', error)
  const settle = () => page.evaluate(async () => {
    await document.fonts.ready
    await Promise.all(document.getAnimations().map(a => a.finished.catch(() => {})))
    scrollTo(0, 0)
  })
  const theme = value => page.getByRole('combobox', { name: 'Tema da interface' }).selectOption(value)
  const screenshot = (name, fullPage = true) => page.screenshot({ path: `output/playwright/redesign03/after/${name}.png`, fullPage })
  try {
    await page.goto(origin + '/app/dashboard')
    await page.evaluate(() => localStorage.setItem('app_music_sidebar_collapsed', 'false'))
    await page.reload()
    for (const mode of ['light', 'dark']) {
      await theme(mode)
      for (const [name, path] of [['dashboard', '/app/dashboard'], ['percepcao', '/app/playground?activity=percepcao']]) {
        const response = await page.goto(origin + path)
        check(response.status() === 200, `${name} HTTP ${response.status()}`)
        for (const [width,height] of [[360,640],[390,844],[768,1024],[820,1180],[1024,768],[1440,900],[1920,1080]]) {
          await page.setViewportSize({width,height})
          await settle()
          const geometry = await page.evaluate(() => {
            const controls = [...document.querySelectorAll('.app-topbar button,.app-topbar select,.profile-link,.study-index__entry,.perception-option,.playground-player-button,.playground-next-button,.playground-activity-card')]
              .filter(e => e.getClientRects().length)
            return { overflow: document.documentElement.scrollWidth > innerWidth + 1,
              narrowControls: controls.filter(e => e.getBoundingClientRect().height < 44 || e.getBoundingClientRect().width < 44).map(e=>e.textContent.trim()),
              headings: document.querySelectorAll('h1').length, root: document.body.classList.contains('study-editorial'),
              answers: document.querySelectorAll('.perception-option').length,
              family: getComputedStyle(document.querySelector('h1')).fontFamily,
              background: getComputedStyle(document.body).backgroundColor }
          })
          check(!geometry.overflow, `${name} ${mode} ${width}: horizontal overflow`)
          check(!geometry.narrowControls.length, `${name} ${width}: target below 44px ${geometry.narrowControls}`)
          check(geometry.headings === 1 && geometry.root, `${name}: heading/scope`)
          if (name === 'percepcao') check(geometry.answers === 4, 'Four answers required')
          await screenshot(`${name}-${mode}-${width}x${height}`)
          result.matrix.push({name,mode,width,height,...geometry})
        }
      }
      result.contrast.push(...await page.evaluate(mode => {
        const root = document.body, style = getComputedStyle(root)
        const names = ['--ui-ink','--ui-muted','--ui-primary','--ui-on-primary','--ui-control-border','--ui-focus','--ui-success','--ui-success-bg','--ui-danger','--ui-danger-bg','--ui-bg','--ui-surface','--ui-soft']
        const values = Object.fromEntries(names.map(n=>[n,style.getPropertyValue(n).trim()]))
        const luminance = hex => {
          const v=hex.replace('#',''), s=v.length===3?v.split('').map(c=>c+c).join(''):v
          const rgb=[0,2,4].map(i=>parseInt(s.slice(i,i+2),16)/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4)
          return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722
        }
        const pairs=[]
        for(const surface of ['--ui-bg','--ui-surface','--ui-soft']) for(const text of ['--ui-ink','--ui-muted']) pairs.push([text,surface,4.5])
        pairs.push(['--ui-on-primary','--ui-primary',4.5],['--ui-success','--ui-success-bg',4.5],['--ui-danger','--ui-danger-bg',4.5],['--ui-control-border','--ui-surface',3],['--ui-focus','--ui-surface',3])
        return pairs.map(([fg,bg,minimum])=>{const a=luminance(values[fg]),b=luminance(values[bg]);return{mode,fg,bg,foreground:values[fg],background:values[bg],ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05),minimum}})
      }, mode))
    }
    check(result.contrast.every(c=>c.ratio>=c.minimum),'Contrast pair below required ratio')
    await page.goto(origin + '/app/dashboard')
    await page.setViewportSize({width:390,height:844})
    await settle()
    const toggle = page.locator('button[aria-controls=platform-sidebar]')
    const sidebar = page.locator('#platform-sidebar')
    await toggle.click()
    check(await sidebar.getAttribute('aria-modal')==='true', 'Drawer modality')
    check(await page.locator('.app-workspace').evaluate(e=>e.inert), 'Workspace must be inert')
    check(await page.evaluate(()=>document.body.style.overflow)==='hidden','Scroll lock')
    await screenshot('drawer-mobile-dark', false)
    await toggle.click()
    check(await toggle.getAttribute('aria-expanded')==='false','Same button must close')
    await toggle.click()
    await sidebar.locator('a').first().focus()
    await page.keyboard.press('Shift+Tab')
    check(await sidebar.locator('button[type=submit]').evaluate(e=>e===document.activeElement),'Reverse focus trap')
    await page.keyboard.press('Tab')
    check(await sidebar.locator('a').first().evaluate(e=>e===document.activeElement),'Forward focus trap')
    await page.keyboard.press('Escape')
    check(await toggle.evaluate(e=>e===document.activeElement),'Restore opener focus')
    await toggle.click()
    await page.locator('.app-backdrop').click({position:{x:370,y:400}})
    check(await toggle.getAttribute('aria-expanded')==='false','Outside click close')
    result.interactions.push('same opener closes; both focus traps; Escape; focus restore; outside click; inert and scroll lock')
    await theme('light')
    for(const [width,height] of [[768,1024],[820,1180],[1024,768]]) {
      await page.setViewportSize({width,height})
      await settle()
      check(Math.round(await sidebar.evaluate(e=>e.getBoundingClientRect().width))===76,'Tablet rail width')
      await toggle.click()
      check(await sidebar.getAttribute('aria-modal')==='true','Tablet drawer')
      await screenshot(`drawer-tablet-light-${width}`, false)
      await page.keyboard.press('Escape')
    }
    await page.setViewportSize({width:1440,height:900})
    await settle()
    await toggle.click(); await page.reload()
    check(await page.locator('.app-shell').evaluate(e=>e.classList.contains('is-sidebar-collapsed')),'Desktop collapse persistence')
    await toggle.click()
    result.interactions.push('desktop collapse persists; tablet rail/drawer at 768,820,1024')
    await theme('dark'); await page.reload()
    check(await page.locator('html').getAttribute('data-theme')==='dark','Theme reload')
    await page.evaluate(()=>window.studyTurboMarker='retained')
    await Promise.all([page.waitForURL('**/app/playground?activity=percepcao'),page.locator('.study-index__entry[href*="percepcao"]').click()])
    check(await page.evaluate(()=>window.studyTurboMarker==='retained'),'Turbo context')
    check(await page.locator('html').getAttribute('data-bs-theme')==='dark','Bootstrap dark sync')
    await theme('system')
    for(const mode of ['light','dark','light']) {
      await page.emulateMedia({colorScheme:mode})
      await page.waitForFunction(mode=>document.documentElement.dataset.theme===mode,mode)
      check(await page.locator('html').getAttribute('data-bs-theme')===mode,'System/Bootstrap sync')
    }
    await page.reload()
    check(await page.getByRole('combobox',{name:'Tema da interface'}).inputValue()==='system','System preference persisted')
    const second=await page.context().newPage()
    try {
      await second.goto(origin+'/app/dashboard')
      await second.getByRole('combobox',{name:'Tema da interface'}).selectOption('dark')
      await page.waitForFunction(()=>document.documentElement.dataset.theme==='dark')
      await theme('light')
      await second.waitForFunction(()=>document.documentElement.dataset.theme==='light')
    } finally { await second.close() }
    result.interactions.push('explicit theme reload/Turbo; live system changes; cross-tab sync')
    // Scoped body classes must disappear on excluded screens and recover on back navigation.
    await page.goto(origin+'/app/pratica')
    check(!await page.locator('body').evaluate(e=>e.classList.contains('study-editorial')),'Practice is outside approved milestone')
    await page.goBack()
    check(await page.locator('body').evaluate(e=>e.classList.contains('study-editorial')),'Turbo back restores scope')
    await page.emulateMedia({reducedMotion:'reduce'})
    check(await page.evaluate(()=>matchMedia('(prefers-reduced-motion: reduce)').matches),'Reduced motion')
    check(await page.locator('.perception-option').first().evaluate(e=>getComputedStyle(e).transitionDuration)==='0s','Reduced-motion transition')
    // A 640 CSS-pixel viewport exercises the same reflow as a 1280px viewport at 200% zoom.
    await page.setViewportSize({width:640,height:480})
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'200% equivalent reflow')
    result.interactions.push('excluded-screen scope; back navigation; reduced motion; 200% equivalent reflow')
    await page.emulateMedia({reducedMotion:'no-preference',colorScheme:'light'})
    check(!result.errors.length,`Browser errors: ${result.errors.join('; ')}`)
    await page.evaluate(result => { window.__studyEditorialResults = result }, result)
    return result
  } finally { page.off('pageerror',error) }
}
