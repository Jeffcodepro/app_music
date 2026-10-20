// Use only the synthetic account on the dedicated isolated browser server.
export default async function verifyListeningLevels(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use the isolated browser server')
  const results = { profiles: [], screens: [], menu: {} }
  const check = (ok, message) => { if (!ok) throw Error(message) }
  const settle = () => page.evaluate(async () => {
    await document.fonts.ready
    await Promise.all(document.getAnimations().filter(a => a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})))
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
  })
  await page.setViewportSize({ width: 1440, height: 1000 })
  for (const [activity, mode, player] of [['percepcao','interval','interval'], ['harmonia','mixed','harmony'], ['percepcao','melodic_dictation','melody']]) {
    for (let level = 1; level <= 4; level++) {
      await page.goto(`${origin}/app/playground?activity=${activity}&question_mode=${mode}&level=${level}&instrument=piano`)
      await page.locator(`[data-${player}-player-exercise-signature-value]`).waitFor()
      check(await page.locator('select[name=level]').inputValue() === String(level), 'Wrong selected level')
      check(await page.locator('.perception-options button').count() === 4, 'Four choices required')
      const assignment = await page.locator(`[data-${player}-player-exercise-signature-value]`).getAttribute(`data-${player}-player-exercise-signature-value`)
      const profile = { activity, mode, level, assignment }
      if (player === 'melody') {
        Object.assign(profile, await page.locator('[data-controller~="melody-player"]').evaluate(el => ({
          voices: +el.dataset.melodyPlayerVoiceCountValue, events: JSON.parse(el.dataset.melodyPlayerEventsValue).length,
          totalSteps: +el.dataset.melodyPlayerTotalStepsValue, staves: el.querySelector('.voiced-score').querySelectorAll('.voiced-staff').length
        })))
        check(profile.staves <= 2 && profile.staves >= 1, 'Grand staff must use at most two staves')
      }
      results.profiles.push(profile)
      await page.goto(`${origin}/app/playground?activity=${activity}`)
      check(await page.locator(`[data-${player}-player-exercise-signature-value]`).getAttribute(`data-${player}-player-exercise-signature-value`) === assignment, 'Bare reload changed assignment')
    }
  }
  // Change a level through the visible form and verify Turbo replaces the phrase.
  await page.locator('.playground-settings > summary').click()
  const previous = await page.locator('[data-melody-player-exercise-signature-value]').getAttribute('data-melody-player-exercise-signature-value')
  await page.locator('select[name=level]').selectOption('3')
  await page.waitForFunction(old => document.querySelector('[data-melody-player-exercise-signature-value]')?.dataset.melodyPlayerExerciseSignatureValue !== old, previous)
  check(await page.locator('[data-melody-player-voice-count-value]').getAttribute('data-melody-player-voice-count-value') === '2', 'UI level did not change voices')
  await page.locator('.playground-settings > summary').click()
  for (const [width, height] of [[1440,1000], [768,1024], [360,844]]) {
    await page.setViewportSize({ width, height })
    for (const theme of ['light','dark']) {
      await page.locator('.theme-picker > summary').click()
      await page.getByRole('button', {name: theme === 'light' ? 'Claro' : 'Escuro', exact:true}).click()
      await settle()
      const bounds = await page.locator('.voiced-score-scroll').first().evaluate(el => ({
        scrollable: el.scrollWidth > el.clientWidth, width: el.clientWidth, scrollWidth:el.scrollWidth,
        overflow:document.documentElement.scrollWidth > innerWidth,
        scoreHeight:el.querySelector('svg').getBoundingClientRect().height
      }))
      check(!bounds.overflow, 'Page overflow')
      check(bounds.scoreHeight > 140, 'Multivoice score clipped')
      if (width === 360) {
        check(bounds.scrollable, 'Mobile score must remain legible and scrollable')
        const region = page.locator('.voiced-score-scroll').first()
        await region.focus();await page.keyboard.press('ArrowRight')
        await page.waitForFunction(()=>document.querySelector('.voiced-score-scroll').scrollLeft > 0)
        await region.evaluate(el => el.scrollLeft = 0)
      }
      await page.screenshot({path:`output/playwright/listening-levels/dictation-level3-${theme}-${width}.png`,fullPage:true})
      results.screens.push({viewportWidth:width,theme,...bounds})
    }
  }
  await page.setViewportSize({width:1440,height:1000})
  await page.goto(origin+'/app/dashboard')
  const toggle = () => page.getByRole('button',{name:'Abrir ou recolher menu',exact:true})
  for (const rail of [false,true]) {
    const collapsed = await page.locator('.app-shell').evaluate(el=>el.classList.contains('is-sidebar-collapsed'))
    if(collapsed !== rail)await toggle().click()
    await settle()
    await page.locator('.account-menu > summary').click()
    await page.waitForFunction(()=>document.querySelector('.account-menu > summary').getAttribute('aria-expanded') === 'true')
    const box = await page.locator('.account-menu__panel').boundingBox()
    const trigger = await page.locator('.account-menu > summary').boundingBox()
    check(box.y+box.height < trigger.y && box.x >= 0 && box.x+box.width <=1440, 'Menu clipped or not above account')
    check(await page.locator('.account-menu__panel button').isVisible(), 'Logout hidden')
    await page.screenshot({path:`output/playwright/listening-levels/account-${rail?'rail':'expanded'}.png`})
    await page.keyboard.press('Escape')
    check(await page.locator('.account-menu > summary').evaluate(el => el === document.activeElement), 'Escape did not restore focus')
    results.menu[rail?'rail':'expanded'] = box
  }
  await page.setViewportSize({width:360,height:844})
  await toggle().click()
  await page.locator('.account-menu > summary').click()
  await page.waitForFunction(()=>document.querySelector('.account-menu > summary').getAttribute('aria-expanded')==='true')
  await page.screenshot({path:'output/playwright/listening-levels/account-mobile.png'})
  await page.keyboard.press('Escape')
  check(await page.locator('.app-shell').evaluate(el=>el.classList.contains('is-drawer-open')), 'First Escape closed drawer')
  await page.keyboard.press('Escape')
  check(await page.locator('.app-shell').evaluate(el=>!el.classList.contains('is-drawer-open')&&!el.querySelector('.app-workspace').inert), 'Second Escape failed to restore workspace')
  await toggle().click();await page.locator('.account-menu > summary').click()
  await page.getByRole('link',{name:'Configurações',exact:true}).click()
  await page.waitForURL('**/app/perfil')
  check(await page.locator('.app-shell').evaluate(el=>!el.classList.contains('is-drawer-open')), 'Account navigation left drawer open')
  results.menu.mobileEscapeAndNavigation = true
  return results
}
