// Long text is injected into the rendered UI only; no user data is changed.
export default async function verifyContentResilience(page) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin) throw Error('Use the isolated server')
  const results=[]
  await page.goto(origin+'/app/dashboard')
  for(const [width,height] of [[360,640],[820,1180],[1440,900]]) {
    await page.setViewportSize({width,height})
    await page.locator('.page-heading h1').evaluate(e=>e.textContent='Olá, '+ 'Estudante'.repeat(35)+'.')
    const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)
    if(overflow) throw Error('Long unbroken student name overflows dashboard')
    await page.screenshot({path:`output/playwright/uiux02-integral/after/texto-longo-${width}.png`,fullPage:true})
    results.push({width,height,unbrokenNameCharacters:315,overflow})
  }
  await page.goto(origin+'/app/perfil')
  await page.setViewportSize({width:360,height:640})
  await page.getByLabel('Nome completo',{exact:true}).fill('Estudante de música com um nome composto e extenso para verificar a interface')
  await page.getByLabel('Objetivo de estudo',{exact:true}).fill('Practice reading and listening to musical intervals, with a detailed and extended study goal.')
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)
  if(overflow) throw Error('Long profile form overflow')
  await page.screenshot({path:'output/playwright/uiux02-integral/after/perfil-texto-longo.png',fullPage:true})
  await page.goto(origin+'/app/dashboard')
  return {results,unsavedFormLongPortugueseAndEnglish:true}
}
