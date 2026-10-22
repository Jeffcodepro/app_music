// Authenticated fictitious account, isolated Rails server; no real student data.
export default async function verifyAudio(page) {
  const origin = "http://127.0.0.1:3001"
  if (new URL(page.url()).origin !== origin) throw new Error("Use the isolated test server")
  const results = []
  const ready = () => page.waitForFunction(() => {
    const c = window.__uxPlayer
    return c && !c.isPlaying && c.playbackChannel().lastPlayedDigest === c.currentPlaybackDigest()
  })
  for (const [area, identifier, action] of [["percepcao", "interval-player", "Tocar intervalo"], ["harmonia", "harmony-player", "Ouvir vozes juntas"]]) {
    await page.goto(`${origin}/app/playground?activity=${area}&instrument=piano&question_mode=quality`)
    await page.waitForLoadState("networkidle")
    await page.evaluate(identifier => {
      const element = document.querySelector(`[data-controller~="${identifier}"]`)
      const c = window.Stimulus.getControllerForElementAndIdentifier(element, identifier)
      window.__uxPlayer = c
      window.__uxCalls = []
      const player = c.cacheState.soundfontPlayers.piano
      if (!player || player.name !== "acoustic_grand_piano") throw new Error("Piano sample program not loaded")
      const original = player.play
      player.play = (...args) => { window.__uxCalls.push(args); return original.apply(player, args) }
    }, identifier)
    await page.getByRole("button", { name: new RegExp(action) }).click()
    if (!['loading','playing'].includes(await page.locator('.playback-status').getAttribute('data-state'))) throw Error('Missing visible pending playback state')
    const lockedWhilePlaying = await page.evaluate(() => window.__uxPlayer.playbackChannel().lastPlayedDigest === null)
    if (!lockedWhilePlaying) throw new Error("Answer unlocked before audio ended")
    await ready()
    if (await page.locator('.playback-status').getAttribute('data-state') !== 'completed') throw Error('Missing visible completed playback state')
    const first = await page.evaluate(() => ({ calls: window.__uxCalls, diagnostics: window.__appMusicAudioDiagnostics,
      pitches: window.__uxPlayer.sequenceValue?.map(c => c.pitches),
      ready: window.__uxPlayer.playbackChannel().lastPlayedDigest === window.__uxPlayer.currentPlaybackDigest() }))
    if (!first.calls.length || !first.ready) throw new Error("Sample playback failed")
    if (area === "harmonia" && !first.calls.every(call => call[1] === first.calls[0][1])) throw new Error("Chord voices not simultaneous")
    await page.getByRole("button", { name: area === "percepcao" ? "Repetir intervalo" : "Repetir a última escuta", exact: true }).click()
    await ready()
    const repetitions = await page.evaluate(() => window.__uxCalls.length)
    if (repetitions !== first.calls.length * 2) throw new Error("Repeat changed the sequence")
    await page.getByRole("button", { name: area === "percepcao" ? "Repetir intervalo" : "Repetir a última escuta", exact: true }).click()
    await page.waitForFunction(() => window.__uxPlayer.isPlaying && window.__uxPlayer.playbackChannel().activePlaybackHandles.length > 0)
    await page.locator(".playground-next-button").click()
    await page.waitForFunction(() => !window.__uxPlayer.element.isConnected)
    const stopped = await page.evaluate(() => window.__uxPlayer.playbackChannel().activePlaybackHandles.length === 0)
    if (!stopped) throw new Error("Old playback survived exercise change")
    results.push({ area, engine: "soundfont", repeat: true, stoppedOnNext: stopped, ...first })
  }
  await page.route("https://gleitz.github.io/**", route => route.abort())
  try {
    for (const [area, identifier, action, synthMethod] of [["percepcao", "interval-player", "Tocar intervalo", "playWithSynth"], ["harmonia", "harmony-player", "Ouvir vozes juntas", "playSequenceWithSynth"]]) {
      await page.goto(`${origin}/app/playground?activity=${area}&instrument=piano&question_mode=quality`)
      await page.waitForLoadState("networkidle")
      await page.evaluate(identifier => {
        window.__uxPlayer = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(`[data-controller~="${identifier}"]`), identifier)
      }, identifier)
      await page.getByRole("button", { name: new RegExp(action) }).click()
      await ready()
      const diagnostic = await page.evaluate(() => window.__appMusicAudioDiagnostics.findLast(e => e.engine === "synth"))
      if (!diagnostic) throw new Error("Network failure did not use synth fallback")
      results.push({ area, engine: "synth", networkBlocked: true, ready: true, diagnostic })
      // Simulate failure of the remaining audio engine on this fictitious round.
      await page.evaluate(method => {
        window.__uxPlayer[method] = () => { throw new Error("simulated output failure") }
        window.__uxPlayer.stop()
      }, synthMethod)
      await page.getByRole("button", { name: new RegExp(action) }).click()
      await page.locator("[data-playback-error]").waitFor({ state: "visible" })
      if (await page.locator('.playback-status').getAttribute('data-state') !== 'unavailable') throw Error('Missing visible unavailable playback state')
      let posts = 0
      const count = request => { if (request.method() === "POST") posts++ }
      page.on("request", count)
      await page.locator(".perception-option").first().click()
      page.off("request", count)
      const neutral = await page.evaluate(() => !window.__uxPlayer.isPlaying && window.__uxPlayer.playbackChannel().lastPlayedDigest === null)
      if (!neutral || posts !== 0) throw new Error("Failed audio counted as an answer")
      results.push({ area, completeFailure: true, neutral, answerPosts: posts })
    }
  } finally {
    await page.unroute("https://gleitz.github.io/**")
  }
  await page.goto(`${origin}/app/playground?activity=ritmica`)
  await page.evaluate(() => {
    window.__rhythmPlayer = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~=rhythm-player]'), 'rhythm-player')
  })
  await page.getByRole('button',{name:/Ouvir o padrão atual/}).click()
  await page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='playing')
  await page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='completed')
  if(!await page.evaluate(()=>window.__rhythmPlayer.audioState.lastPlayedSignature===window.__rhythmPlayer.exerciseSignatureValue)) throw Error('Rhythm completed before readiness')
  results.push({area:'ritmica',engine:'synth',visibleCompletion:true})
  await page.evaluate(()=>{window.__rhythmPlayer.performPlayback=()=>{throw Error('simulated rhythm output failure')}})
  await page.getByRole('button',{name:/Ouvir o padrão atual/}).click()
  await page.locator('[data-playback-error]').waitFor({state:'visible'})
  let posts=0
  const count=request=>{if(request.method()==='POST')posts++}
  page.on('request',count)
  try { await page.locator('.perception-option').first().click() } finally {page.off('request',count)}
  const neutral=await page.evaluate(()=>window.__rhythmPlayer.audioState.lastPlayedSignature===null)
  if(!neutral || posts || await page.locator('.playback-status').getAttribute('data-state')!=='unavailable') throw Error('Rhythm failure was not visibly neutral')
  results.push({area:'ritmica',completeFailure:true,neutral,answerPosts:posts})
  return results
}
