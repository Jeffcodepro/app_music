// Anonymous routes on the isolated server; inspect reset form with a synthetic token only.
export default async function verifyAuthUI(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use isolated browser server')
  await page.goto(origin + '/users/sign_in')
  if (!await page.locator('input[name="user[email]"]').count()) throw Error('Sign out of the synthetic account before running the anonymous matrix')
  const routes = [['entrar','/users/sign_in'],['cadastro','/users/sign_up'],['recuperacao','/users/password/new'],['nova-senha','/users/password/edit?reset_password_token=uiux02-render-token']]
  const results = []
  for (const theme of ['light','dark']) {
    await page.getByRole('combobox',{name:'Tema da interface'}).selectOption(theme)
    for (const [name,path] of routes) {
      const response = await page.goto(origin + path)
      if (response.status() !== 200) throw Error(`${path}: ${response.status()}`)
      for (const [width,height] of [[390,844],[820,1180],[1440,900]]) {
        await page.setViewportSize({width,height})
        await page.evaluate(async()=>{await document.fonts.ready;await Promise.all(document.getAnimations().map(a=>a.finished.catch(()=>{})))})
        const metrics = await page.evaluate(()=>({theme:document.documentElement.dataset.theme,overflow:document.documentElement.scrollWidth>innerWidth,heading:document.querySelector('h1').textContent,unlabeled:[...document.querySelectorAll('input:not([type=hidden]):not([type=submit]),select')].filter(e=>!e.labels?.length&&!e.getAttribute('aria-label')).map(e=>e.name)}))
        if (metrics.overflow || metrics.unlabeled.length || metrics.theme !== theme) throw Error(`${name}: invalid layout/labels/theme`)
        await page.screenshot({path:`output/playwright/uiux02-integral/after/${name}-${theme}-${width}.png`,fullPage:true})
        results.push({route:path.replace('uiux02-render-token',':synthetic-token'),name,width,height,...metrics})
      }
    }
  }
  // Deliberately wrong synthetic login exercises error feedback without sending mail.
  await page.goto(origin + '/users/sign_in')
  await page.getByLabel(/^E-mail/).fill('uiux02@example.test')
  await page.getByLabel(/^Senha/).fill('invalid-local-password')
  await page.getByRole('button',{name:'Entrar',exact:true}).click()
  await page.locator('.flash-item--alert').waitFor()
  const loginError = await page.locator('.flash-item--alert').innerText()
  await page.getByLabel(/^Senha/).fill('uiux02-local-test')
  await Promise.all([page.waitForURL('**/app/**'),page.getByRole('button',{name:'Entrar',exact:true}).click()])
  return {matrix:results,loginError,loginRestored:true}
}
