// Run with a synthetic account on the separately isolated browser DB, never real data.
export default async function verifyCompactExercises(page) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Use the isolated local server')
  const results={screens:[],themes:[],keyboard:[],crossTab:false}
  const check=(v,message)=>{if(!v)throw Error(message)}
  const settle=()=>page.evaluate(async()=>{await document.fonts.ready;await Promise.all(document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))})
  const choose=async mode=>{await page.locator('.theme-picker > summary').click();await page.getByRole('button',{name:{light:'Claro',dark:'Escuro',system:'Sistema'}[mode],exact:true}).click();await settle()}
  for(const mode of ['light','dark','system']){
    await choose(mode)
    const state=await page.evaluate(()=>{const n=document.querySelector('.theme-picker > summary');return{preference:document.documentElement.dataset.themePreference,resolved:document.documentElement.dataset.theme,bootstrap:document.documentElement.dataset.bsTheme,stored:localStorage.getItem('app_music_theme'),iconText:n.innerText.trim(),focusVisible:n.matches(':focus-visible'),outlineStyle:getComputedStyle(n).outlineStyle,closed:!n.parentElement.open}})
    check(state.preference===mode&&state.stored===mode&&state.closed&&!state.iconText&&!state.focusVisible&&state.outlineStyle==='none','Theme pointer selection leaves no persistent outline')
    await page.reload();check(await page.evaluate(()=>document.documentElement.dataset.themePreference)===mode,'Theme survives reload')
    results.themes.push(state)
  }
  await page.emulateMedia({colorScheme:'dark'});await page.waitForFunction(()=>document.documentElement.dataset.theme==='dark')
  await page.emulateMedia({colorScheme:'light'});await page.waitForFunction(()=>document.documentElement.dataset.theme==='light')
  await page.getByRole('link',{name:'Prática',exact:true}).click();await page.waitForURL('**/app/pratica')
  check(await page.locator('.listening-note').count()===0,'No instruction sidebar')
  check(await page.locator('.study-index__entry').count()===4,'Four practice destinations')
  const scenarios=[['reading','/app/playground?activity=leitura'],['interval','/app/playground?activity=percepcao'],['rhythm','/app/playground?activity=ritmica&activity_mode=subdivision'],['harmony','/app/playground?activity=harmonia'],['melody','/app/playground?activity=percepcao&question_mode=melodic_dictation'],['practice','/app/pratica']]
  for(const [size,width,height] of [['desktop',1440,1000],['tablet',820,1180],['mobile',390,844]]){
    await page.setViewportSize({width,height});await settle()
    for(const [name,path] of scenarios){
      await page.goto(origin+path)
      for(const mode of ['light','dark']){
        await choose(mode);await page.locator('h1').click();await page.evaluate(()=>scrollTo(0,0));await settle()
        const measurement=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,options:[...document.querySelectorAll('.perception-option')].map(n=>({height:n.getBoundingClientRect().height,font:getComputedStyle(n.querySelector('.perception-option__label')||n).fontSize})),theme:document.documentElement.dataset.theme,themeText:document.querySelector('.theme-picker > summary').innerText.trim()}))
        check(!measurement.overflow,`${name}/${size}/${mode}: overflow`)
        if(name!=='practice')check(measurement.options.length===4,`${name}: four answers`)
        check(!measurement.themeText,'Icon-only theme')
        const screenshot=`output/playwright/compact-exercises/${name}-${size}-${mode}.png`
        await page.screenshot({path:screenshot,fullPage:true});results.screens.push({name,size,mode,screenshot,...measurement})
      }
    }
  }
  await page.setViewportSize({width:1440,height:1000});await page.goto(origin+'/app/pratica')
  await page.locator('.theme-picker > summary').focus();await page.keyboard.press('Enter')
  await page.getByRole('button',{name:'Claro',exact:true}).focus();await page.keyboard.press('Enter')
  const focus=await page.locator('.theme-picker > summary').evaluate(n=>({focus:n.matches(':focus'),visible:n.matches(':focus-visible'),outline:getComputedStyle(n).outline,closed:!n.parentElement.open}))
  check(focus.focus&&focus.visible&&focus.closed,'Keyboard choice restores visible focus')
  await page.keyboard.press('Enter');await page.keyboard.press('Escape');check(!await page.locator('.theme-picker').evaluate(n=>n.open),'Escape closes theme')
  results.keyboard.push(focus)
  const other=await page.context().newPage()
  try{
    await other.goto(origin+'/app/perfil')
    await other.getByRole('combobox',{name:'Tema da interface',exact:true}).selectOption('dark')
    await page.waitForFunction(()=>document.documentElement.dataset.theme==='dark')
    check(await page.locator('[data-theme-target=choice][value=dark]').getAttribute('aria-pressed')==='true','Cross-tab icon update')
    results.crossTab=true
    await choose('system');await other.waitForFunction(()=>document.querySelector('[data-theme-target=select]').value==='system')
  }finally{await other.close()}
  return results
}
