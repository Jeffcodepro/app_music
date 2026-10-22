// Rendered text in compact exercises; scoped contrast check, not a WCAG certification.
export default async function verifyDashboardMeterContrast(page) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Use the isolated test server')
  const results=[]
  for(const theme of ['light','dark']) {
    await page.locator('.theme-picker > summary').click(); await page.getByRole('button',{name:theme==='light'?'Claro':'Escuro',exact:true}).click(); await page.evaluate(async()=>await Promise.all(document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{}))))
    for(const [name,path]of [['dashboard','/app/dashboard'],['dictation','/app/playground?activity=percepcao&question_mode=melodic_dictation'],['compound','/app/playground?activity=ritmica&level=2&meter_id=6-8'],['additive','/app/playground?activity=ritmica&level=4&meter_id=5-8-2-3']]) {
      await page.goto(origin+path)
      const measurements=await page.evaluate(()=>{
        const rgb=s=>(s.match(/[\d.]+/g)||[]).slice(0,3).map(Number)
        const luminance=c=>{const v=c.map(n=>n/255).map(n=>n<=.04045?n/12.92:((n+.055)/1.055)**2.4);return v[0]*.2126+v[1]*.7152+v[2]*.0722}
        const values=[],walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT)
        for(let node=walker.nextNode();node;node=walker.nextNode()) {
          const text=node.textContent.trim(),el=node.parentElement
          if(!text||!el||el.closest('script,style,[aria-hidden=true],[hidden]'))continue
          const rect=el.getBoundingClientRect(),style=getComputedStyle(el)
          if(!el.getClientRects().length||rect.bottom<0||style.visibility==='hidden')continue
          let bg=null
          for(let p=el;p;p=p.parentElement){const c=getComputedStyle(p).backgroundColor;if(c!=='transparent'&&c!=='rgba(0, 0, 0, 0)'){bg=c;break}}
          if(!bg)continue
          const a=luminance(rgb(style.color)),b=luminance(rgb(bg))
          values.push({text:text.slice(0,70),foreground:style.color,background:bg,ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)})
        }
        return values
      })
      const failures=measurements.filter(m=>m.ratio<4.5)
      if(failures.length)throw Error(`${name} ${theme}: ${JSON.stringify(failures)}`)
      results.push({name,theme,count:measurements.length,minimum:Math.min(...measurements.map(m=>m.ratio)),measurements})
    }
  }
  return results
}
