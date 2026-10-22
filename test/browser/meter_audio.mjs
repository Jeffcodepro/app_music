export default async function verifyMeterAudio(page){
 const origin='http://127.0.0.1:3001';if(new URL(page.url()).origin!==origin)throw Error('Use isolated test server')
 const results=[]
 for(const [meter,level,mode,measure,unit,bars,clicks,accents]of[
  ['2-4',1,'pulse',8,4,2,[0,4],[0]],['6-8',2,'subdivision',12,6,1,[0,6],[0]],['5-8-2-3',4,'precision',10,2,1,[0,2,4,6,8],[0,4]]]){
  await page.goto(`${origin}/app/playground?activity=ritmica&level=${level}&meter_id=${meter}&activity_mode=${mode}`)
  await page.waitForFunction(()=>window.Stimulus?.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="rhythm-player"]'),'rhythm-player'))
  await page.evaluate(()=>{const c=window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~="rhythm-player"]'),'rhythm-player');window.__meterPlayer=c;window.__meterHits=[];window.__meterClicks=[];const hit=c.scheduleRhythmHit,click=c.scheduleMetronomeClick,play=c.performMetricalPlayback;c.scheduleRhythmHit=function(...args){window.__meterHits.push(args);return hit.apply(this,args)};c.scheduleMetronomeClick=function(...args){window.__meterClicks.push(args);return click.apply(this,args)};c.performMetricalPlayback=async function(...args){const duration=await play.apply(this,args);window.__meterDuration=duration;return duration}})
  await page.getByRole('button',{name:'Tocar ditado rítmico',exact:true}).click()
  await page.waitForFunction(()=>document.querySelector('.playback-status').dataset.state==='completed')
  const observed=await page.evaluate(()=>({hits:window.__meterHits,clicks:window.__meterClicks,duration:window.__meterDuration,bpm:window.__meterPlayer.tempoBpmValue,events:window.__meterPlayer.eventsValue,meter:window.__meterPlayer.meterValue,metronome:window.__meterPlayer.metronomeDuringPatternValue}))
  const step=60/observed.bpm/unit
  if(observed.hits.length!==observed.events.length||Math.abs(observed.duration-(.17+measure*(1+bars)*step))>1e-6)throw Error('Wrong duration/pass count')
  const start=observed.clicks[0][0]
  observed.hits.forEach((hit,i)=>{if(Math.abs(hit[0]-start-(measure+observed.events[i].start_step)*step)>1e-6)throw Error('Wrong onset')})
  const expected=clicks.map(tick=>[tick*step,accents.includes(tick)])
  if(observed.metronome)for(let bar=0;bar<bars;bar++)expected.push(...clicks.map(tick=>[(measure*(bar+1)+tick)*step,accents.includes(tick)]))
  if(expected.length!==observed.clicks.length)throw Error('Wrong count-in')
  expected.forEach((value,i)=>{if(Math.abs(observed.clicks[i][0]-start-value[0])>1e-6||observed.clicks[i][1]!==value[1])throw Error('Wrong group accent')})
  results.push({meter,onePass:true,countInOneBar:true,...observed})
 }
 await page.evaluate(()=>{window.__meterPlayer.ensureAudioContext=async()=>{throw Error('simulated output failure')}})
 await page.getByRole('button',{name:'Repetir a última escuta',exact:true}).click();await page.locator('[data-playback-error]').waitFor()
 let posts=0;const counter=r=>{if(r.method()==='POST'&&r.url().includes('/app/playground/answer'))posts++};page.on('request',counter)
 await page.locator('.rhythm-options button').first().click();page.off('request',counter)
 const neutral=await page.evaluate(()=>document.querySelector('.playback-status').dataset.state==='unavailable'&&window.__meterPlayer.audioState.lastPlayedSignature===null)
 if(posts!==0||!neutral)throw Error('Audio failure submitted a response')
 return{cases:results,failure:{neutral,posts}}
}
