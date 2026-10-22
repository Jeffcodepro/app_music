export default async function verifyCompactExerciseMode(page) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Use isolated browser DB')
  await page.goto(origin+'/app/playground?activity=percepcao')
  if(!await page.locator('.playground-settings').evaluate(n=>n.open))await page.locator('.playground-settings > summary').click()
  await page.getByRole('radio',{name:'Ditado melódico · 1 voz',exact:true}).check()
  await page.waitForURL('**/*question_mode=melodic_dictation*')
  await page.locator('[data-controller="melody-player preferences"]').waitFor()
  const signature=await page.locator('[data-melody-player-exercise-signature-value]').getAttribute('data-melody-player-exercise-signature-value')
  await page.reload()
  if(await page.locator('[data-melody-player-exercise-signature-value]').getAttribute('data-melody-player-exercise-signature-value')!==signature)throw Error('Reload lost dictation assignment')
  if(!await page.locator('.playground-settings').evaluate(n=>n.open))await page.locator('.playground-settings > summary').click()
  await page.getByRole('radio',{name:'Flauta',exact:true}).check()
  await page.waitForFunction(()=>document.querySelector('[data-melody-player-instrument-value="flute"]'))
  await page.reload()
  if(await page.locator('[data-melody-player-instrument-value="flute"]').count()!==1)throw Error('Reload lost instrument')
  return {selectedThroughUI:true,modeSurvivesReload:true,sameAssignmentOnReload:true,instrumentSurvivesReload:true,url:page.url()}
}
