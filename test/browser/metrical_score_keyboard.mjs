export default async function verifyMetricalScoreKeyboard(page) {
  const origin = 'http://127.0.0.1:3001'
  if (new URL(page.url()).origin !== origin) throw Error('Use isolated browser server')
  await page.setViewportSize({ width: 360, height: 844 })
  await page.goto(`${origin}/app/playground?activity=ritmica&level=3&meter_id=12-4&activity_mode=precision`)
  const index = await page.locator('.rhythm-score-scroll').evaluateAll(nodes => nodes.findIndex(n => n.scrollWidth > n.clientWidth))
  if (index < 0) throw Error('Missing dense score fixture')
  const score = page.locator('.rhythm-score-scroll').nth(index)
  await score.focus()
  const before = await score.evaluate(n => ({ left: n.scrollLeft, width: n.clientWidth, scrollWidth: n.scrollWidth }))
  for (let i = 0; i < 5; i++) await page.keyboard.press('ArrowRight')
  await page.waitForFunction(i => document.querySelectorAll('.rhythm-score-scroll')[i].scrollLeft > 0, index)
  const after = await score.evaluate(n => ({ left: n.scrollLeft, focusVisible: n.matches(':focus-visible') }))
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)
  if (!after.focusVisible || overflow) throw Error('Focus or page overflow regression')
  await page.screenshot({ path: 'output/playwright/dashboard-meters/dense-score-keyboard-pan.png', fullPage: true })
  return { before, after, documentOverflow: overflow }
}
