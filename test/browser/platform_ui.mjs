// Invoke with Playwright's page, authenticated with a synthetic account on :3001.
// Screenshots and metrics are review evidence, never production user data.
export default async function verifyPlatformUI(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use the isolated browser server on port 3001')
  const check = (condition, message) => { if (!condition) throw Error(message) }
  const settle = async () => page.evaluate(async () => {
    await document.fonts.ready
    await Promise.all(document.getAnimations().map(animation => animation.finished.catch(() => {})))
    window.scrollTo(0, 0)
  })
  const errors = []
  const onError = error => errors.push(error.message)
  page.on('pageerror', onError)
  const result = { matrix: [], interactions: [], errors }
  try {
    await page.goto(`${origin}/app/dashboard`)
    await page.setViewportSize({ width: 390, height: 844 })
    const toggle = page.getByRole('button', { name: 'Abrir ou recolher menu' })
    const sidebar = page.locator('#platform-sidebar')
    await toggle.click()
    check(await sidebar.getAttribute('aria-modal') === 'true', 'Drawer must be modal')
    check(await page.locator('.app-workspace').evaluate(e => e.inert), 'Background must be inert')
    check(await page.evaluate(() => document.body.style.overflow) === 'hidden', 'Background scroll must be locked')
    const sameToggle = page.locator('button[aria-controls=platform-sidebar]')
    await sameToggle.click()
    check(await sameToggle.getAttribute('aria-expanded') === 'false', 'Same opening control closes drawer')
    await sameToggle.click()
    // Keyboard wrap must remain inside the sidebar in both directions.
    await sidebar.locator('a,button').first().focus()
    await page.keyboard.press('Shift+Tab')
    check(await sidebar.locator('button[type=submit]').evaluate(e => e === document.activeElement), 'Reverse focus trap')
    await page.keyboard.press('Tab')
    check(await sidebar.locator('a').first().evaluate(e => e === document.activeElement), 'Forward focus trap')
    await page.keyboard.press('Escape')
    check(await toggle.evaluate(e => e === document.activeElement), 'Restore opener focus')
    check(await toggle.getAttribute('aria-expanded') === 'false', 'Drawer closed state')
    await toggle.click()
    await page.locator('.app-backdrop').click({ position: { x: 370, y: 300 } })
    check(await toggle.getAttribute('aria-expanded') === 'false', 'Outside click closes drawer')
    await toggle.click()
    await page.screenshot({ path: 'output/playwright/uiux02-integral/after/menu-mobile.png' })
    await Promise.all([page.waitForURL('**/app/aulas'), sidebar.getByRole('link', { name: 'Aulas', exact: true }).click()])
    check(!await page.locator('.app-workspace').evaluate(e => e.inert), 'Navigation unlocks workspace')
    check(await page.locator('[data-testid=lessons-preparing]').count() === 1, 'Honest lessons empty state')
    result.interactions.push('mobile drawer: open, trap both ways, Escape, restore focus, outside click, route close')
    // Repeated Turbo transitions must not accumulate listeners or preserve open drawers.
    await page.evaluate(() => { window.uiuxTurboMarker = 'preserved' })
    for (let i = 0; i < 3; i++) {
      await page.getByRole('button', { name: 'Abrir ou recolher menu' }).click()
      await Promise.all([page.waitForURL('**/app/dashboard'), page.locator('.app-side-menu').getByRole('link', { name: 'Dashboard', exact: true }).click()])
      check(await page.evaluate(() => window.uiuxTurboMarker) === 'preserved', 'Expected Turbo navigation, not full reload')
      await page.getByRole('button', { name: 'Abrir ou recolher menu' }).click()
      check(await page.locator('#platform-sidebar').getAttribute('aria-modal') === 'true', 'One toggle opens after Turbo')
      await page.keyboard.press('Escape')
      if (i < 2) {
        await page.getByRole('button', { name: 'Abrir ou recolher menu' }).click()
        await Promise.all([page.waitForURL('**/app/aulas'), page.locator('.app-side-menu').getByRole('link', { name: 'Aulas', exact: true }).click()])
      }
    }
    result.interactions.push('three repeated Turbo cycles preserve JS state and single menu behavior')
    // Desktop collapse persists, tablet rail has a modal expansion.
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.getByRole('button', { name: 'Abrir ou recolher menu' }).click()
    check(await page.locator('.app-shell').evaluate(e => e.classList.contains('is-sidebar-collapsed')), 'Desktop collapse')
    await page.reload()
    check(await page.locator('.app-shell').evaluate(e => e.classList.contains('is-sidebar-collapsed')), 'Collapse persists')
    await page.getByRole('button', { name: 'Abrir ou recolher menu' }).click()
    for (const [width, height] of [[768,1024],[820,1180],[1024,768]]) {
      await page.setViewportSize({ width, height })
      check(Math.round(await sidebar.evaluate(e => e.getBoundingClientRect().width)) === 76, 'Tablet rail')
      await page.getByRole('button', { name: 'Abrir ou recolher menu' }).click()
      check(await sidebar.getAttribute('aria-modal') === 'true', 'Tablet drawer')
      await page.screenshot({ path: `output/playwright/uiux02-integral/after/menu-${width}.png` })
      await page.keyboard.press('Escape')
    }
    result.interactions.push('desktop collapse persistence; tablet rail/drawer portrait and landscape')
    // Explicit theme, reload, Turbo and OS preference changes.
    await page.getByRole('combobox', { name: 'Tema da interface' }).first().selectOption('dark')
    await page.reload()
    check(await page.locator('html').getAttribute('data-theme') === 'dark', 'Theme survives reload')
    await page.getByRole('combobox', { name: 'Tema da interface' }).first().selectOption('system')
    await page.emulateMedia({ colorScheme: 'dark' })
    await page.waitForFunction(() => document.documentElement.dataset.theme === 'dark')
    check(await page.locator('html').getAttribute('data-theme') === 'dark', 'System dark')
    await page.emulateMedia({ colorScheme: 'light' })
    await page.waitForFunction(() => document.documentElement.dataset.theme === 'light')
    result.interactions.push('theme persistence; system preference updates live')
    const routes = [
      ['dashboard','/app/dashboard'], ['trilhas','/app/trilhas'],
      ...['leitura','ritmica','percepcao','harmonia','apreciacao','historia'].map(area => [`tema-${area}`,`/app/trilhas/tema/${area}`]),
      ['trilha-legada','/app/trilhas/leitura/1'], ['aulas','/app/aulas'],
      ['aula-guiada-legada','/app/aulas/guia-leitura?mode=guiado'], ['aula-livre-legada','/app/aulas/intro-leitura?mode=livre'],
      ['pratica','/app/pratica'], ['historico','/app/pratica/resultado'],
      ...['leitura','percepcao','ritmica','harmonia'].map(area => [area,`/app/playground?activity=${area}`]),
      ['carreira','/app/carreira'], ['arena','/app/arena'], ['conta','/app/perfil'], ['nivelamento','/app/nivelamento'],
      ['desafios','/app/desafios'], ['ranking','/app/ranking'], ['conquistas','/app/conquistas'], ['bolsa','/app/bolsa-evolucao'],
      ['planos','/app/assinatura/comparacao'], ['cobrancas','/app/assinatura/historico'],
      ...['welcome','objective','profile','result','plan'].map(step => [`onboarding-${step}`,`/onboarding/${step}`]),
      ['credenciais','/users/edit']
    ]
    const baseSizes = [[390,844],[820,1180],[1440,900]]
    const allSizes = [[360,640],[375,667],...baseSizes, [768,1024],[1024,768],[1366,768],[1920,1080]]
    const complex = ['dashboard','conta','leitura','percepcao','ritmica','harmonia']
    for (const theme of ['light','dark']) {
      await page.getByRole('combobox', { name: 'Tema da interface' }).first().selectOption(theme)
      for (const [name,path] of routes) {
        const response = await page.goto(origin + path)
        check(response.status() === 200, `${path} HTTP ${response.status()}`)
        for (const [width,height] of complex.includes(name) ? allSizes : baseSizes) {
          await page.setViewportSize({ width, height })
          await settle()
          const metrics = await page.evaluate(() => {
            const main = document.querySelector('main').getBoundingClientRect()
            const visible = e => !!e.getClientRects().length && getComputedStyle(e).visibility !== 'hidden' && !e.closest('[inert]')
            return {
              theme: document.documentElement.dataset.theme,
              overflow: document.documentElement.scrollWidth > innerWidth + 1,
              main: { x: Math.round(main.x), width: Math.round(main.width) },
              headings: [...document.querySelectorAll('h1')].map(e => e.textContent.trim()),
              inertButtons: [...document.querySelectorAll('button[type=button]:not([data-action])')].filter(visible).map(e => e.textContent.trim()),
              brokenLinks: [...document.querySelectorAll('a[href="#"],a:not([href])')].filter(visible).map(e => e.textContent.trim()),
              unlabeledFields: [...document.querySelectorAll('input:not([type=hidden]):not([type=submit]), select, textarea')].filter(visible).filter(e => !e.labels?.length && !e.getAttribute('aria-label') && !e.getAttribute('aria-labelledby')).map(e => e.name),
              answers: [...document.querySelectorAll('.playground-response-panel form')].map(form => ({ action: new URL(form.action).pathname, id: !!form.querySelector('[name=assignment_id]')?.value, token: !!form.querySelector('[name=attempt_token]')?.value })),
              score: [...document.querySelectorAll('.reading-notation-card svg,.rhythm-notation-card svg')].map(svg => ({ width: Math.round(svg.getBoundingClientRect().width), ink: getComputedStyle(svg.querySelector('[fill="#1c1917"]')).fill, paper: getComputedStyle(svg.querySelector('[fill="#fcfbf8"]')).fill }))
            }
          })
          check(metrics.theme === theme, `${name}: theme persistence`)
          check(!metrics.overflow, `${name} ${width}: horizontal overflow`)
          check(metrics.headings.length === 1, `${name}: one h1`)
          check(!metrics.inertButtons.length, `${name}: inert buttons`)
          check(!metrics.brokenLinks.length, `${name}: dead links`)
          check(!metrics.unlabeledFields.length, `${name}: missing labels ${metrics.unlabeledFields}`)
          if (['leitura','percepcao','ritmica','harmonia'].includes(name)) check(metrics.answers.length === 4 && metrics.answers.every(a => a.id && a.token && a.action === '/app/playground/answer'), `${name}: four answer contracts`)
          await page.screenshot({ path: `output/playwright/uiux02-integral/after/${name}-${theme}-${width}.png`, fullPage: true })
          result.matrix.push({ route: path, name, width, height, ...metrics })
        }
      }
    }
    check(!errors.length, `Browser errors: ${errors.join('; ')}`)
    return result
  } finally { page.off('pageerror', onError) }
}
