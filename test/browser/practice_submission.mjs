// Supply answers read from the synthetic user's assignments in the private DB.
// Never derive the answer from DOM metadata or bypass the playback guard.
export default async function verifyPracticeSubmissions(page, correctAnswers) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin) throw Error('Use the isolated server')
  const results=[]
  for(const [area,play] of [['leitura',null],['percepcao','Tocar intervalo'],['ritmica','Ouvir o padrão atual'],['harmonia','Ouvir vozes juntas']]) {
    await page.goto(`${origin}/app/playground?activity=${area}`)
    const id=await page.locator('.playground-response-panel [name=assignment_id]').first().inputValue()
    if(!correctAnswers[id]) throw Error('Prepare the current synthetic assignments and read their answers from the isolated DB first')
    if(play) {
      await page.getByRole('button',{name:new RegExp(play)}).click()
      await page.waitForFunction(()=>document.querySelector('.playback-status')?.dataset.state==='completed')
    }
    const form=page.locator('.playground-response-panel form').filter({has:page.locator(`input[name=selected_option_id][value="${correctAnswers[id]}"]`)})
    const token=await form.locator('input[name=attempt_token]').inputValue()
    await form.locator('button').click()
    await page.locator('.playground-feedback.is-correct').waitFor()
    await page.screenshot({path:`output/playwright/uiux02-integral/after/resposta-${area}.png`,fullPage:true})
    results.push({area,correctFeedback:true,hadAssignment:!!id,hadToken:!!token})
  }
  await page.goto(origin+'/app/dashboard')
  const dashboard={attempts:await page.locator('[data-testid=attempt-count]').innerText(),xp:await page.locator('[data-testid=xp-total]').innerText(),rows:await page.locator('[data-testid=history-row]').count()}
  if(dashboard.attempts!=='4' || dashboard.xp!=='80' || dashboard.rows!==4) throw Error('Fresh synthetic dashboard must contain exactly four responses and 80 XP')
  await page.screenshot({path:'output/playwright/uiux02-integral/after/dashboard-com-atividade.png',fullPage:true})
  await page.goto(origin+'/app/pratica/resultado')
  if(await page.locator('[data-testid=history-row]').count()!==4) throw Error('History missing persisted responses')
  await page.screenshot({path:'output/playwright/uiux02-integral/after/historico-com-atividade.png',fullPage:true})
  return {results,dashboard,historyRows:4}
}
