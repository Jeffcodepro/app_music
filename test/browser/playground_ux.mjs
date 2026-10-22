// Run against an authenticated, fictitious account on the separate test server.
// The caller supplies Playwright's page; no browser/dependency is installed here.
export default async function verifyPlaygrounds(page, options = {}) {
  const origin = "http://127.0.0.1:3001"
  if (new URL(page.url()).origin !== origin) throw new Error("Use the isolated browser server on port 3001")
  const directory = options.directory || "output/playwright/uiux02-integral/notation"
  const scenarios = options.scenarios || ["leitura", "percepcao", "harmonia", "ritmica"].map(area => ({ area, query: "", label: area }))
  const sizes = options.sizes || [[1366, 768], [1440, 900], [390, 844], [375, 667]]
  const check = (condition, message) => { if (!condition) throw new Error(message) }
  const errors = []
  const onError = error => errors.push(error.message)
  page.on("pageerror", onError)
  const metrics = []
  try {
  for (const {area, query, label} of scenarios) {
    await page.goto(`${origin}/app/playground?activity=${area}${query}`)
    await page.locator(".playground-stage").waitFor()
    await page.waitForLoadState("networkidle")
    for (const [width, height] of sizes) {
      await page.setViewportSize({ width, height })
      await page.evaluate(async () => {
        await document.fonts.ready
        await Promise.all(document.getAnimations().map(animation => animation.finished.catch(() => {})))
        window.scrollTo(0, 0)
      })
      const result = await page.evaluate(() => {
        const box = selector => {
          const element = document.querySelector(selector)
          if (!element) return null
          const b = element.getBoundingClientRect()
          return { top: Math.round(b.top + scrollY), height: Math.round(b.height), width: Math.round(b.width) }
        }
        const clipped = []
        document.querySelectorAll(".reading-notation-card svg, .rhythm-notation-card svg").forEach(svg => {
          const bounds = svg.viewBox.baseVal
          svg.querySelectorAll("text, g, line, ellipse, path").forEach(element => {
            const b = element.getBBox()
            const matrix = svg.getScreenCTM().inverse().multiply(element.getScreenCTM())
            const corners = [[b.x, b.y], [b.x + b.width, b.y], [b.x, b.y + b.height], [b.x + b.width, b.y + b.height]]
              .map(([x, y]) => new DOMPoint(x, y).matrixTransform(matrix))
            if (corners.some(p => p.x < bounds.x || p.y < bounds.y || p.x > bounds.x + bounds.width || p.y > bounds.y + bounds.height)) {
              clipped.push({ tag: element.tagName, text: element.textContent.trim() })
            }
          })
        })
        return { viewport: [innerWidth, innerHeight], musicalArea: box(".reading-notation-card, .harmony-player-panel, .playground-player-controls"),
          trainer: box(".playground-trainer"), answers: box(".perception-options"),
          pageHeight: document.documentElement.scrollHeight,
          horizontalOverflow: document.documentElement.scrollWidth > innerWidth,
          answerHeights: [...document.querySelectorAll(".perception-option")].map(e => e.getBoundingClientRect().height), clipped }
      })
      check(!result.horizontalOverflow, `${area} ${width}: horizontal overflow`)
      check(result.clipped.length === 0, `${area} ${width}: clipped music`)
      check(result.answerHeights.every(height => height >= 44), `${area}: small answer targets`)
      check(result.answerHeights.length === 4, "Four answers required")
      metrics.push({ area, variant: label, ...result })
      const name = label === "leitura" ? "reading" : label
      await page.screenshot({ path: `${directory}/after-${name}-${width}.png`, fullPage: true })
    }
  }
  check(errors.length === 0, errors.join("; "))
  return { cases: metrics.length, errors, metrics }
  } finally { page.off("pageerror", onError) }
}
