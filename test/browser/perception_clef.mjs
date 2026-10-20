// Run with the synthetic authenticated account on the isolated browser server.
export default async function verifyPerceptionClef(page) {
  if (new URL(page.url()).origin !== 'http://127.0.0.1:3001') throw Error('Use isolated server')
  await page.reload()
  const results = []
  for (const [size, width, height] of [['desktop', 1440, 1000], ['mobile', 360, 844]]) {
    await page.setViewportSize({ width, height })
    for (const theme of ['light', 'dark']) {
      await page.locator('.theme-picker > summary').click()
      await page.getByRole('button', { name: theme === 'light' ? 'Claro' : 'Escuro', exact: true }).click()
      await page.locator('h1').click()
      await page.evaluate(async () => { await document.fonts.ready })
      const geometry = await page.locator('.melody-options svg').evaluateAll(scores => scores.map(svg => {
        const clef = svg.querySelector('.melody-clef')
        if (!clef) throw Error('Missing vector clef')
        const origin = new DOMPoint(0, 0).matrixTransform(clef.transform.baseVal.consolidate().matrix)
        const box = clef.querySelector('path').getBBox()
        const matrix = clef.transform.baseVal.consolidate().matrix
        const corners = [new DOMPoint(box.x, box.y), new DOMPoint(box.x + box.width, box.y + box.height)].map(p => p.matrixTransform(matrix))
        const bounds = { left: Math.min(...corners.map(p => p.x)), right: Math.max(...corners.map(p => p.x)), top: Math.min(...corners.map(p => p.y)), bottom: Math.max(...corners.map(p => p.y)) }
        const lines = [...svg.querySelectorAll('g[stroke] > line')].filter(n => n.getAttribute('x1') === '24').map(n => Number(n.getAttribute('y1')))
        const time = [...svg.querySelectorAll('text')].map(n => n.getBBox().x)
        return { origin: { x: origin.x, y: origin.y }, bounds, lines, timeLeft: Math.min(...time), notes: [...svg.querySelectorAll('.melody-note')].map(n => [Number(n.getAttribute('cx')), Number(n.getAttribute('cy'))]), textClef: [...svg.querySelectorAll('text')].some(n => n.textContent.includes('𝄞')) }
      }))
      for (const score of geometry) {
        if (score.origin.y !== 106 || score.lines[3] !== score.origin.y || score.textClef) throw Error('Musical anchor regression')
        if (score.bounds.top < 0 || score.bounds.bottom > 194 || score.bounds.right >= score.timeLeft) throw Error('Clipped or overlapping clef')
      }
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)
      if (overflow) throw Error('Document overflow')
      const screenshot = `output/playwright/perception-clef/after-${size}-${theme}.png`
      await page.locator('.melody-options').screenshot({ path: screenshot })
      results.push({ size, theme, geometry, overflow, screenshot })
    }
  }
  return results
}
