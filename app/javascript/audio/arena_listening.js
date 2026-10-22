// One gesture unlocks the contexts used by all four existing exercise players.
// This is deliberately in-memory: a full reload may require another gesture.
export async function activateArenaAudio() {
  const root = window.__appMusicAudioCache ||= {}
  const harmony = root.harmony ||= {}
  const rhythm = window.__appMusicAudio ||= {}
  const AudioContext = window.AudioContext || window.webkitAudioContext
  const context = [root.synthContext, harmony.synthContext, rhythm.synthContext].find(item => item && item.state !== "closed") || new AudioContext()
  for (const cache of [root, harmony, rhythm]) {
    if (!cache.synthContext || cache.synthContext.state === "closed") cache.synthContext = context
  }
  const contexts = [...new Set([root.synthContext, harmony.synthContext, rhythm.synthContext])]
  const pending = contexts.map(item => item.state === "suspended" ? item.resume() : Promise.resolve())
  if (window.Tone?.start) pending.push(window.Tone.start().catch(() => {}))
  await Promise.all(pending)
  if (contexts.some(item => item.state !== "running")) throw new Error("Audio permission required")
  window.__appMusicArenaAudioEnabled = true
  window.dispatchEvent(new CustomEvent("arena:audio-enabled"))
}
