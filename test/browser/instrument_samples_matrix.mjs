export default async function verifyInstrumentSamples(page, activity) {
  const origin='http://127.0.0.1:3001'
  if(new URL(page.url()).origin!==origin)throw Error('Use isolated test server')
  const dictation=activity==='ditado',routeActivity=dictation?'percepcao':activity
  const player=dictation?'melody':activity==='percepcao'?'interval':'harmony',mode=dictation?'melodic_dictation':player==='interval'?'interval':'quality'
  const expected={piano:'acoustic_grand_piano',flute:'flute',clarinet:'clarinet',guitar:'acoustic_guitar_nylon',organ:'church_organ'}
  const results=[]
  for(const [instrument,program]of Object.entries(expected)){
    await page.goto(`${origin}/app/playground?activity=${routeActivity}&question_mode=${mode}&level=1&instrument=${instrument}`)
    if(!await page.locator('.playground-settings').evaluate(el=>el.open))await page.locator('.playground-settings >summary').click()
    for(let level=1;level<=(dictation&&instrument!=='piano'?3:4);level++){
      if(level>1){
        const old=await page.locator(`[data-${player}-player-exercise-signature-value]`).getAttribute(`data-${player}-player-exercise-signature-value`)
        await page.locator('select[name=level]').selectOption(String(level))
        await page.waitForFunction(({player,old})=>document.querySelector(`[data-${player}-player-exercise-signature-value]`)?.getAttribute(`data-${player}-player-exercise-signature-value`)!==old,{player,old})
      }
      await page.waitForFunction(player=>{const el=document.querySelector(`[data-controller~="${player}-player"]`);return el&&window.Stimulus.getControllerForElementAndIdentifier(el,`${player}-player`)},player)
      const sample=await page.locator(`[data-controller~="${player}-player"]`).evaluate(async(el,player)=>{
        const c=window.Stimulus.getControllerForElementAndIdentifier(el,`${player}-player`),p=await c.soundfontInstrument()
        const pitches=player==='interval'?[c.firstPitchValue,c.secondPitchValue]:player==='melody'?c.eventsValue.map(event=>event.pitch):c.sequenceValue.flatMap(chord=>chord.pitches)
        const midis=pitches.map(pitch=>window.Tone.Frequency(c.normalizePitchForSoundfont(pitch)).toMidi())
        if(!midis.every(midi=>p.buffers[midi]?.length>0))throw Error('Missing decoded sample')
        const buffer=p.buffers[60],data=buffer.getChannelData(0);let sum=0,peak=0
        for(let i=0;i<data.length;i++){sum+=data[i]*data[i];peak=Math.max(peak,Math.abs(data[i]))}
        return{instrument:c.instrumentValue,loadedProgram:p.name,url:p.url,pitches,midis,sample:{duration:buffer.duration,sampleRate:buffer.sampleRate,rms:Math.sqrt(sum/data.length),peak}}
      },player)
      if(sample.loadedProgram!==program||sample.instrument!==instrument)throw Error('Incorrect sampled program')
      results.push({activity,level,...sample})
    }
    // Native playback of the most advanced level, after real CDN decoding.
    const button=player==='interval'?page.getByRole('button',{name:'Tocar intervalo',exact:true}):player==='melody'?page.getByRole('button',{name:'Tocar ditado melódico',exact:true}):page.locator(`button[data-action="${player}-player#${['piano','guitar','organ'].includes(instrument)?'playBlocked':'playBroken'}"]`)
    await button.click()
    await page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='completed')
    const engine=await page.evaluate(()=>window.__appMusicAudioDiagnostics.at(-1).engine)
    if(engine!=='soundfont')throw Error('Native sampled playback was not completed')
    results.at(-1).nativePlayback=engine
  }
  return results
}
