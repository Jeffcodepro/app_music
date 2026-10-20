// Use only the synthetic authenticated account on the isolated browser server.
export default async function verifyMeterSettings(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use isolated browser server')
  const errors = []
  const errorListener = error => errors.push(error.message)
  page.on('pageerror', errorListener)
  try {
    await page.goto(`${origin}/app/playground?activity=ritmica&level=1&meter_id=4-4&activity_mode=mixed`)
    const openSettings = async () => {
      if (!await page.locator('.playground-settings').evaluate(n => n.open)) {
        await page.locator('.playground-settings > summary').click()
      }
    }
    await openSettings()
    const initialOptions = await page.locator('select[name=meter_id] option').count()
    if (initialOptions !== 4) throw Error('Level 1 catalog mismatch')
    await page.getByLabel('Nível de dificuldade', { exact: true }).selectOption('4')
    await page.waitForFunction(() => document.querySelectorAll('select[name=meter_id] option').length === 42)
    await openSettings()
    await page.getByLabel('Compasso', { exact: true }).selectOption('13-16-3-3-3-2-2')
    await page.waitForFunction(() => {
      const n = document.querySelector('[data-rhythm-player-meter-value]')
      const meter = n && JSON.parse(n.dataset.rhythmPlayerMeterValue)
      return meter?.numerator === 13 && meter?.denominator === 16
    })
    await openSettings()
    await page.locator('input[name=activity_mode][value=pulse]').check()
    await page.waitForFunction(() => new URL(location.href).searchParams.get('activity_mode') === 'pulse')
    const identity = () => page.locator('[data-rhythm-player-exercise-signature-value]').getAttribute('data-rhythm-player-exercise-signature-value')
    const before = await identity()
    await page.reload()
    if (await identity() !== before) throw Error('Reload replaced the assignment')
    await page.goto(`${origin}/app/playground?activity=ritmica`)
    if (await identity() !== before) throw Error('Bare navigation replaced the assignment')
    const preferences = await page.evaluate(() => ({
      level: document.querySelector('select[name=level]').value,
      meter: document.querySelector('select[name=meter_id]').value,
      mode: document.querySelector('input[name=activity_mode]:checked').value,
      catalogCount: document.querySelectorAll('select[name=meter_id] option').length,
      overflow: document.documentElement.scrollWidth > innerWidth
    }))
    if (preferences.level !== '4' || preferences.meter !== '13-16-3-3-3-2-2' || preferences.mode !== 'pulse' || preferences.overflow) throw Error('Preferences or layout mismatch')
    if (errors.length) throw Error(errors.join('\n'))
    return { initialOptions, preferences, sameAssignmentAfterReloadAndNavigation: true, errors }
  } finally {
    page.off('pageerror', errorListener)
  }
}
