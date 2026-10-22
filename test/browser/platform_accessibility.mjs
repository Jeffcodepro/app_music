// Focus, contrast tokens, storage synchronization and reflow; not a WCAG certification.
export default async function verifyPlatformAccessibility(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use the isolated server')
  const check = (value, message) => { if (!value) throw Error(message) }
  await page.goto(origin + '/app/perfil')
  const other = await page.context().newPage()
  try {
    await other.goto(origin + '/app/perfil')
    await other.getByRole('combobox', {name:'Tema da interface'}).first().selectOption('light')
    await page.waitForFunction(() => document.documentElement.dataset.theme === 'light')
    await other.getByRole('combobox', {name:'Tema da interface'}).last().selectOption('dark')
    await page.waitForFunction(() => document.documentElement.dataset.theme === 'dark')
    check((await page.getByRole('combobox',{name:'Tema da interface'}).evaluateAll(es=>es.map(e=>e.value))).every(v=>v==='dark'),'Cross-tab controls synchronize')
  } finally { await other.close() }
  const contrasts = []
  for (const theme of ['light','dark']) {
    await page.getByRole('combobox',{name:'Tema da interface'}).first().selectOption(theme)
    contrasts.push(...await page.evaluate(theme => {
      const styles = getComputedStyle(document.body)
      const color = name => styles.getPropertyValue(name).trim()
      const luminance = hex => {
        const rgb = [1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4)
        return rgb.reduce((s,c,i)=>s+c*[.2126,.7152,.0722][i],0)
      }
      return [
        ['text','--ui-ink','--ui-surface',4.5], ['secondary text','--ui-muted','--ui-surface',4.5],
        ['secondary text on soft','--ui-muted','--ui-soft',4.5], ['link','--ui-primary','--ui-surface',4.5],
        ['primary button','--ui-on-primary','--ui-primary',4.5], ['focus','--ui-focus','--ui-bg',3],
        ['control boundary','--ui-control-border','--ui-surface',3], ['score','--score-ink','--score-paper',4.5],
        ['score staff','--score-staff','--score-paper',3], ['success','--ui-success','--ui-success-bg',4.5],
        ['error','--ui-danger','--ui-danger-bg',4.5], ['target','--ui-accent','--ui-accent-soft',4.5]
      ].map(([purpose,fg,bg,minimum])=>{
        const a=luminance(color(fg)), b=luminance(color(bg));return {theme,purpose,foreground:color(fg),background:color(bg),ratio:Number(((Math.max(a,b)+.05)/(Math.min(a,b)+.05)).toFixed(2)),minimum}
      })
    },theme))
  }
  check(contrasts.every(c=>c.ratio>=c.minimum),'Token contrast below minimum')
  await page.setViewportSize({width:390,height:844})
  await page.getByRole('button',{name:'Abrir ou recolher menu'}).click()
  await Promise.all([page.waitForURL('**/app/aulas'),page.locator('.app-side-menu').getByRole('link',{name:'Aulas',exact:true}).click()])
  await page.goBack()
  check(!await page.locator('.app-workspace').evaluate(e=>e.inert),'Turbo back restores operable background')
  check(await page.getByRole('button',{name:'Abrir ou recolher menu'}).getAttribute('aria-expanded')==='false','Turbo back must not cache open drawer')
  await page.goto(origin + '/app/playground?activity=leitura')
  await page.emulateMedia({reducedMotion:'reduce'})
  const motion = await page.locator('.perception-option').first().evaluate(e=>getComputedStyle(e).transitionDuration)
  check(motion.split(',').every(v=>parseFloat(v)===0),'Reduced motion')
  await page.setViewportSize({width:1366,height:768})
  const session = await page.context().newCDPSession(page)
  try {
    await session.send('Emulation.setDeviceMetricsOverride',{width:683,height:384,deviceScaleFactor:2,mobile:false})
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'200% equivalent reflow')
    await page.screenshot({path:'output/playwright/uiux02-integral/after/reflow-200-equivalent.png',fullPage:true})
  } finally { await session.send('Emulation.clearDeviceMetricsOverride'); await session.detach() }
  await page.setViewportSize({width:390,height:844})
  await page.emulateMedia({reducedMotion:'no-preference'})
  return {contrasts,crossTabTheme:true,turboBack:true,reducedMotion:motion,reflow:'CDP 683×384 at scale 2; equivalent reflow, not native browser zoom'}
}
