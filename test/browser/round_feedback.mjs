// Run in two phases with references read only from the synthetic account's DB.
// Phase one creates the next assignments. Read those references before phase two.
export default async function verifyRoundFeedback(page, answers, phase = 'transition') {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Use the isolated test server')
  const check=(value,message)=>{if(!value)throw Error(message)}
  const results=[]
  for(const [area,frame,identifier,play]of [['leitura','reading',null,null],['ritmica','rhythm','rhythm-player','Ouvir o padrão atual'],['harmonia','harmony','harmony-player','Ouvir vozes juntas']]) {
    await page.goto(`${origin}/app/playground?activity=${area}`)
    await page.setViewportSize({width:1440,height:900})
    await page.getByRole('combobox',{name:'Tema da interface'}).selectOption('light')
    const id=await page.locator('[name=assignment_id]').first().inputValue()
    check(answers[id],`${area}: missing reference for current isolated assignment`)
    const listen=async()=>{
      if(!play)return
      await page.getByRole('button',{name:new RegExp(play)}).click()
      await page.waitForFunction(()=>document.querySelector('.playback-status')?.dataset.state==='completed')
    }
    const choose=async(correct)=>{
      const match=correct?`[value="${answers[id]}"]`:`:not([value="${answers[id]}"])`
      const form=page.locator('.playground-response-panel form').filter({has:page.locator(`input[name=selected_option_id]${match}`)}).first()
      await form.locator('button').click()
    }
    await listen();await choose(false)
    await page.locator('.playground-feedback.is-incorrect').waitFor()
    check(await page.locator('[name=assignment_id]').first().inputValue()===id,`${area}: wrong answer must keep assignment`)
    check(await page.locator('.playground-previous-result').count()===0,`${area}: old success remained on wrong current answer`)
    if(phase==='transition') {
      await listen();await choose(true)
      await page.waitForFunction(old=>document.querySelector('[name=assignment_id]')?.value!==old,id)
      check(await page.locator('.playground-feedback').count()===0,`${area}: stale feedback appeared in new round`)
      check(await page.locator('.playground-previous-result[role=status]').count()===1,`${area}: missing separated previous result`)
      check(await page.locator('.perception-option[disabled]').count()===0,`${area}: new round was disabled`)
    }
    await page.locator('h1').click()
    await page.evaluate(async()=>{await document.fonts.ready;scrollTo(0,0)})
    await page.screenshot({path:`output/playwright/uiux03/rounds/${area}-${phase}.png`,fullPage:true})
    results.push({area,phase,wrongStayedInAssignment:true,staleCurrentFeedback:false,separatedResult:phase==='transition'})
  }
  return results
}
