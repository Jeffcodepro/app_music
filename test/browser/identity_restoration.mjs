// Real browser checks for the corrective mission. Only the guarded :3001 app
// and its synthetic account may be used; no production/development form posts.
export default async function verifyIdentityRestoration(page) {
  const origin='http://127.0.0.1:3001'
  const check=(condition,message)=>{if(!condition)throw Error(message)}
  check(new URL(page.url()).origin===origin,'Use the private browser server')
  const results={matrix:[],fullPages:[],interactions:[],runtimeErrors:[]}
  const onError=error=>results.runtimeErrors.push(error.message)
  page.on('pageerror',onError)
  const resolved=async expected=>{
    await page.waitForFunction(value=>document.documentElement.dataset.theme===value&&document.documentElement.dataset.bsTheme===value,expected)
  }
  const choose=async value=>{
    await page.locator('.landing-desktop-theme select').selectOption(value)
    await resolved(value==='system'?'light':value)
  }
  try {
    await page.goto(origin)
    await page.setViewportSize({width:1440,height:900})
    await page.emulateMedia({colorScheme:'light'})
    const originalSections=['hero','vantagens','problema','como-funciona','modos-estudo','playgrounds','gamificacao','diversao','conteudo','diferenciais','planos','faq','cta']
    check(JSON.stringify(await page.locator('section').evaluateAll(es=>es.map(e=>e.id)))===JSON.stringify(originalSections),'Original section order')
    for(const theme of ['light','dark']) {
      await page.setViewportSize({width:1440,height:900})
      await choose(theme)
      for(const [width,height] of [[360,640],[375,667],[390,844],[768,1024],[820,1180],[1024,768],[1366,768],[1440,900],[1920,1080]]) {
        await page.setViewportSize({width,height})
        await page.evaluate(async()=>{await document.fonts.ready;scrollTo(0,0)})
        await page.waitForFunction(()=>[...document.querySelectorAll('#hero .reveal')].every(e=>Number(getComputedStyle(e).opacity)>.99))
        const metric=await page.evaluate(()=>({theme:document.documentElement.dataset.theme,bootstrap:document.documentElement.dataset.bsTheme,
          overflow:document.documentElement.scrollWidth>innerWidth,heroFont:getComputedStyle(document.querySelector('h1')).fontFamily,
          video:document.querySelector('video').getAttribute('src'),h1:document.querySelector('h1').innerText,
          ctaBottom:document.querySelector('#hero .btn-beam').getBoundingClientRect().bottom,
          heroBottom:document.querySelector('#hero').getBoundingClientRect().bottom,
          controls:[...document.querySelectorAll('[data-theme-target=select]')].map(e=>e.value)}))
        check(!metric.overflow,`Horizontal overflow at ${width} ${theme}`)
        check(metric.heroFont.includes('Nunito'),'Original heading font')
        check(metric.ctaBottom<=metric.heroBottom+1,`Hero action clipped at ${width}`)
        check(metric.controls.every(value=>value===theme),'All theme selectors synchronized')
        await page.screenshot({path:`output/playwright/identity-restoration/hero-${theme}-${width}.png`})
        results.matrix.push({width,height,...metric})
      }
      // A real reduced-motion preference exposes every section, unlike the
      // historical full-page shots whose offscreen reveals remained invisible.
      await page.emulateMedia({reducedMotion:'reduce'})
      await page.waitForFunction(()=>[...document.querySelectorAll('.reveal')].every(e=>e.classList.contains('active')))
      check(await page.locator('video').evaluateAll(es=>es.every(e=>e.paused)),'Reduced motion pauses both original video layers')
      for(const [width,height] of [[390,844],[820,1180],[1440,900]]) {
        await page.setViewportSize({width,height})
        await page.screenshot({path:`output/playwright/identity-restoration/full-${theme}-${width}-reduced-motion.png`,fullPage:true})
        results.fullPages.push({theme,width,height,reducedMotion:true})
      }
      await page.emulateMedia({reducedMotion:'no-preference'})
    }
    await page.setViewportSize({width:390,height:844})
    const toggle=page.locator('button[aria-controls=public-menu]')
    await toggle.click()
    check(await page.locator('#public-menu').getAttribute('aria-modal')==='true','Restored mobile menu modal')
    await page.locator('#public-menu select').selectOption('light');await resolved('light')
    await page.screenshot({path:'output/playwright/identity-restoration/menu-mobile-light.png'})
    await toggle.click()
    check(await toggle.getAttribute('aria-expanded')==='false','Same control closes menu')
    await toggle.click();await page.keyboard.press('Escape')
    check(await toggle.evaluate(e=>e===document.activeElement),'Return focus after Escape')
    await toggle.click()
    await page.locator('#public-menu').getByRole('link',{name:'Planos',exact:true}).click()
    await page.waitForURL('**/#planos')
    check(!await page.locator('[data-app-shell-target=workspace]').evaluate(e=>e.inert),'Anchor closes and unlocks mobile menu')
    results.interactions.push('Original links, mobile drawer, same toggle, Escape/focus and anchor navigation')
    await page.setViewportSize({width:1440,height:900})
    await choose('system')
    await page.emulateMedia({colorScheme:'dark'});await resolved('dark')
    await page.emulateMedia({colorScheme:'light'});await resolved('light')
    await choose('dark');await page.reload();await resolved('dark')
    check(await page.locator('.landing-desktop-theme select').inputValue()==='dark','Reload persists explicit choice')
    const other=await page.context().newPage()
    try {
      await other.goto(origin)
      await other.locator('.landing-desktop-theme select').selectOption('light');await resolved('light')
      await other.locator('.landing-desktop-theme select').selectOption('dark');await resolved('dark')
    } finally {await other.close()}
    results.interactions.push('System OS changes, explicit preference priority, reload and cross-tab persistence')
    await page.getByRole('link',{name:'Login',exact:true}).click()
    await page.waitForURL('**/users/sign_in');await resolved('dark')
    await page.goBack();await page.waitForURL(url=>url.origin===origin&&url.pathname==='/');await resolved('dark')
    await page.getByRole('link',{name:'Login',exact:true}).click()
    await page.waitForURL('**/users/sign_in')
    await page.waitForLoadState('networkidle')
    await page.getByLabel(/^E-mail/).fill('identity@example.test')
    await page.getByLabel(/^Senha/).fill('identity-local-test')
    await Promise.all([page.waitForURL('**/app/**',{timeout:10000}),page.getByRole('button',{name:'Entrar',exact:true}).click()])
    await resolved('dark')
    await page.goto(origin+'/app/perfil')
    const controls=page.getByRole('combobox',{name:'Tema da interface'})
    check(await controls.count()===2,'Both account selectors exist')
    await controls.last().selectOption('light');await resolved('light')
    check((await controls.evaluateAll(es=>es.map(e=>e.value))).every(value=>value==='light'),'Account selectors synchronize')
    await controls.first().selectOption('dark');await resolved('dark')
    await page.reload();await resolved('dark')
    await page.screenshot({path:'output/playwright/identity-restoration/account-dark.png',fullPage:true})
    // Simulated storage quota: in-memory explicit choice must survive OS events
    // and Turbo rendering, even though a hard reload cannot persist blocked data.
    await controls.first().selectOption('light')
    await page.evaluate(()=>{window.__identitySetItem=Storage.prototype.setItem;Storage.prototype.setItem=()=>{throw Error('simulated quota')}})
    try {
      await controls.last().selectOption('dark')
      await page.emulateMedia({colorScheme:'dark'})
      await page.emulateMedia({colorScheme:'light'})
      await page.evaluate(()=>document.dispatchEvent(new Event('turbo:before-render')))
      await resolved('dark')
      check((await controls.evaluateAll(es=>es.map(e=>e.value))).every(value=>value==='dark'),'Unavailable storage keeps explicit selection')
    } finally {await page.evaluate(()=>Storage.prototype.setItem=window.__identitySetItem)}
    await controls.first().selectOption('dark')
    for(const area of ['leitura','percepcao','ritmica','harmonia']) {
      await page.goto(origin+'/app/playground?activity='+area)
      await resolved('dark')
      check(await page.locator('.playground-response-panel form [name=assignment_id]').count()===4,'Four protected answer identities')
    }
    results.interactions.push('Public/auth navigation and back; synthetic login; both account selectors; unavailable storage; four exercise contracts')
    check(!results.runtimeErrors.length,results.runtimeErrors.join('; '))
    return results
  } finally {page.off('pageerror',onError)}
}
