const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs'), vm = require('node:vm')
const source = fs.readFileSync('app/javascript/controllers/arena_live_controller.js', 'utf8').replace(/^import[^\n]*\n/gm, '').replace('export default class extends Controller', 'class ArenaLive extends Controller')
function harness(responses = []) {
  const listeners = new Map(), timers = new Set()
  const document = { hidden: false, activeElement: null, addEventListener: (k, f) => listeners.set(k, f), removeEventListener: k => listeners.delete(k), querySelector: () => ({ content: 'csrf-fixture' }) }
  const requests = []
  const Live = vm.runInNewContext(`${source}\nArenaLive`, { Controller: class {}, document, Date, Number, AbortController,
    FormData: class { constructor(form) { this.fields = { ...form.fields } } set(key,value) { this.fields[key] = value } },
    setTimeout: () => { const id = {}; timers.add(id); return id }, clearTimeout: id => timers.delete(id), setInterval: () => 1, clearInterval() {},
    fetch: async (url, options) => { requests.push({ url, options }); const value = responses.shift(); if (value instanceof Error) throw value; return value }, navigator: { clipboard: { writeText: async () => {} } } })
  const live = new Live()
  const dataset = { sequence: '1', version: '2', roundId: 'round-fixture', serverNow: new Date().toISOString(), deadline: new Date(Date.now() + 30000).toISOString(), roundState: 'answering' }
  const radio = { value: 'choice-b', checked: true, focus() { this.focused = true } }
  live.contentTarget = { querySelector: selector => selector.startsWith('[data-') ? { dataset } : radio, querySelectorAll: () => [radio], set innerHTML(value) { this.html = value; radio.checked = false } }
  live.connectionTarget = { textContent: '' }; live.timerTarget = { textContent: '' }; live.hasTimerTarget = true
  live.urlValue = '/app/arena/salas/fixture'; live.settleUrlValue = '/settle'
  live.connect()
  return { live, dataset, radio, listeners, timers, document, requests }
}
test('uses server clock offset and pause state without classifying an answer', () => {
  const h = harness()
  h.dataset.serverNow = new Date(Date.now() + 60000).toISOString()
  h.dataset.deadline = new Date(Date.now() + 90000).toISOString()
  h.live.adoptState()
  assert.ok(h.live.remainingSeconds() >= 29 && h.live.remainingSeconds() <= 30)
  h.dataset.roundState = 'paused'; h.live.tick(); assert.equal(h.live.timerTarget.textContent, 'Pausado')
  h.live.disconnect(); assert.equal(h.listeners.size, 0); assert.equal(h.timers.size, 0)
})
test('network failure preserves a selected answer and schedules recovery', async () => {
  const h = harness([new Error('offline')]); await h.live.poll()
  assert.equal(h.radio.checked, true); assert.match(h.live.connectionTarget.textContent, /Reconectando/)
  assert.equal(h.timers.size, 1); h.live.disconnect()
})
test('peer events refresh the view without losing a local selection', async () => {
  const h = harness([{ ok: true, text: async () => '<div>updated room</div>' }])
  h.document.activeElement = { value: h.radio.value, matches: () => true }
  await h.live.refreshContent()
  assert.equal(h.radio.checked, true); assert.equal(h.radio.focused, true)
  assert.equal(h.live.contentTarget.html, '<div>updated room</div>'); h.live.disconnect()
})
test('settlement is a protected POST and never sends a browser timestamp or score', async () => {
  const h = harness([{ ok: true }, { ok: true, text: async () => '<div>results</div>' }]); await h.live.settle()
  assert.equal(h.requests[0].options.method, 'POST')
  assert.equal(h.requests[0].options.headers['X-CSRF-Token'], 'csrf-fixture')
  assert.equal(h.requests[0].options.body, undefined); h.live.disconnect()
})
test('lost authorization stops polling without inventing results', async () => {
  const h = harness([{ status: 404 }]); await h.live.poll()
  assert.equal(h.live.stopped, true); assert.match(h.live.connectionTarget.textContent, /não está disponível/)
  h.live.disconnect()
})
test('keeps the latest choice when the learner changes it during a pending refresh', async () => {
  let resolve
  const pending = new Promise(done => { resolve = done })
  const h = harness([pending]); h.radio.value = 'choice-a'
  const refresh = h.live.refreshContent()
  h.radio.value = 'choice-b'; h.radio.checked = true
  resolve({ ok: true, text: async () => '<div>peer update</div>' })
  await refresh
  assert.equal(h.radio.value, 'choice-b'); assert.equal(h.radio.checked, true)
  h.live.disconnect()
})
test('copy confirmation survives an unchanged poll instead of disappearing with network status', async () => {
  const h = harness([{ ok: true, json: async () => ({ sequence: 1, version: 2, server_now: new Date().toISOString() }) }])
  h.live.hasCopyStatusTarget = true; h.live.copyStatusTarget = { textContent: '' }
  await h.live.copy({ currentTarget: { dataset: { copyText: 'invitation-fixture' }, textContent: 'Copiar link' } })
  await h.live.poll()
  assert.match(h.live.copyStatusTarget.textContent, /Link copiado/)
  h.live.disconnect()
})
test('expiration refreshes the invitation even without a game event', async () => {
  const h = harness([
    { ok: true, json: async () => ({ sequence: 1, version: 2, invite: { expired: true }, server_now: new Date().toISOString() }) },
    { ok: true, text: async () => '<div>Convite expirado</div>' }
  ])
  h.dataset.inviteExpired = 'false'
  await h.live.poll()
  assert.equal(h.live.contentTarget.html, '<div>Convite expirado</div>')
  h.live.disconnect()
})
test('countdown and feedback continue the game through protected settlement', async () => {
  for (const phase of ['countdown', 'feedback']) {
    const h = harness([
      { ok: true, json: async () => ({ sequence: 1, version: 2, state: 'live', experience: 'party', phase, next_transition_at: new Date(Date.now() - 1000).toISOString(), server_now: new Date().toISOString(), round: { state: phase === 'countdown' ? 'ready' : 'results' } }) },
      { ok: true }, { ok: true, text: async () => '<div>next phase</div>' }
    ])
    await h.live.poll()
    assert.equal(h.requests.filter(r => r.options.method === 'POST').length, 1)
    h.live.disconnect()
  }
})
test('animations run once per phase and respect reduced motion', () => {
  const h = harness(); const classes = [], heading = { focus() {} }
  const panel = { classList: { add: value => classes.push(value) }, querySelector: () => heading }
  const original = h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector = selector => selector === '[data-arena-phase-panel]' ? panel : original(selector)
  h.dataset.phase = 'podium'; h.dataset.phaseStartedAt = 'stable-completion-time'
  h.live.adoptState(); h.live.adoptState()
  assert.equal(classes.filter(c => c === 'is-celebrating').length, 1)
  h.live.reducedMotion = () => true; h.dataset.phaseStartedAt = 'another-game'
  h.live.adoptState()
  assert.equal(classes.filter(c => c === 'is-celebrating').length, 1)
  h.live.disconnect()
})
test('an older fragment cannot overwrite a newer game phase', async () => {
  const h = harness([{ ok: true, headers: { get: () => '0' }, text: async () => '<div>old question</div>' }])
  await h.live.refreshContent()
  assert.notEqual(h.live.contentTarget.html, '<div>old question</div>')
  h.live.disconnect()
})
test('answer buttons submit once while a request is pending', async () => {
  let finish
  const pending = new Promise(resolve => { finish = resolve })
  const h = harness([pending, { ok: true, text: async () => '<div>received</div>' }])
  h.dataset.phase = 'question'; h.live.adoptState()
  const event = { preventDefault() {}, currentTarget: { action: '/answer', fields: { idempotency_key: 'same-attempt' } }, submitter: { name: 'option_id', value: 'choice-a' } }
  const first = h.live.submitAnswer(event)
  await h.live.submitAnswer(event)
  assert.equal(h.requests.length, 1)
  finish({ ok: true }); await first
  assert.equal(h.requests[0].options.body.fields.option_id, 'choice-a')
  assert.equal(h.requests[0].options.body.fields.idempotency_key, 'same-attempt')
  assert.equal(h.requests[0].options.headers['X-CSRF-Token'], 'csrf-fixture')
  h.live.disconnect()
})
test('an uncertain submission can retry the same identity without inventing a wrong answer', async () => {
  const h = harness([new Error('offline'), { ok: true }, { ok: true, text: async () => '<div>received</div>' }])
  h.dataset.phase = 'question'; h.live.adoptState()
  h.live.hasAnswerStatusTarget = true; h.live.answerStatusTarget = { textContent: '' }
  const event = { preventDefault() {}, currentTarget: { action: '/answer', fields: { idempotency_key: 'same-attempt' } }, submitter: { name: 'option_id', value: 'choice-a' } }
  await h.live.submitAnswer(event)
  assert.match(h.live.answerStatusTarget.textContent, /não foi marcada como errada/)
  await h.live.submitAnswer(event)
  assert.deepEqual(h.requests[0].options.body.fields, h.requests[1].options.body.fields)
  assert.equal(h.live.answerStatusTarget.textContent, '')
  h.live.disconnect()
})
test('same-question refresh preserves the retry UUID and open host controls with focus', async () => {
  const h = harness([{ ok: true, text: async () => '<div>peer answered</div>' }])
  let identity = { value: 'original-attempt' }, focusCount = 0
  const pause = { dataset: { arenaCommand: 'pause' }, focus() { focusCount++ } }
  let director = { open: true, contains: item => item === pause, querySelector: () => pause }
  const original = h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector = selector => {
    if (selector === 'input[name="idempotency_key"]') return identity
    if (selector === '.arena-director') return director
    return original(selector)
  }
  Object.defineProperty(h.live.contentTarget, 'innerHTML', { set(value) {
    this.html = value; identity = { value: 'new-render-uuid' }
    director = { open: false, contains: item => item === pause, querySelector: () => pause }
  } })
  h.dataset.phase = 'question'; h.live.adoptState(); h.document.activeElement = pause
  await h.live.refreshContent()
  assert.equal(identity.value, 'original-attempt')
  assert.equal(director.open, true)
  assert.equal(focusCount, 1)
  h.live.disconnect()
})

test('a new lobby member animates once while unchanged fragments and reduced motion stay still', () => {
  const h=harness(), classes=[]
  const one={dataset:{arenaMemberKey:'one'},classList:{add:value=>classes.push(['one',value])}}
  const two={dataset:{arenaMemberKey:'two'},classList:{add:value=>classes.push(['two',value])}}
  let players=[one]
  h.live.contentTarget.querySelectorAll=selector=>selector==='[data-arena-member-key]'?players:[]
  h.live.presentPlayers();h.live.presentPlayers()
  players=[one,two];h.live.presentPlayers()
  assert.equal(classes.length,2)
  h.live.reducedMotion=()=>true
  players=[{dataset:{arenaMemberKey:'three'},classList:{add:()=>assert.fail('reduced motion')}}]
  h.live.presentPlayers();h.live.disconnect()
})
test('countdown pulses once per displayed number and never with reduced motion',()=>{
  const h=harness();let animations=0
  h.live.timerTarget.animate=()=>{animations++}
  h.dataset.phase='countdown';h.dataset.nextTransitionAt=new Date(Date.now()+2500).toISOString()
  h.live.adoptState();h.live.tick();h.live.tick();assert.equal(animations,1)
  h.live.reducedMotion=()=>true;h.dataset.nextTransitionAt=new Date(Date.now()+1500).toISOString()
  h.live.adoptState();assert.equal(animations,1);h.live.disconnect()
})
test('a focused closed removal summary retains focus during a peer arrival', async()=>{
  const h=harness([{ok:true,text:async()=>'<div>new member</div>'}]);let focusCount=0
  const summary={closest:()=>({dataset:{arenaMemberControls:'member-a'}}),focus(){focusCount++}}
  const closed={open:false,dataset:{arenaMemberControls:'member-a'},querySelector:()=>summary}
  const old=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=selector=>selector.startsWith('[data-arena-member-controls=')?closed:old(selector)
  h.live.contentTarget.querySelectorAll=selector=>selector==='[data-arena-member-controls]'?[closed]:[]
  h.document.activeElement=summary
  await h.live.refreshContent()
  assert.equal(closed.open,false);assert.equal(focusCount,1);h.live.disconnect()
})
test('host is notified only when a new confirmed player appears, never for initial roster or unchanged poll',()=>{
  const h=harness();h.live.seenMembers.clear();h.live.playersInitialized=false
  h.dataset.host='true';h.dataset.phase='lobby'
  h.live.hasReadyNoticeTarget=true;h.live.readyNoticeTarget={textContent:''}
  const player=name=>({dataset:{arenaMemberKey:name,arenaMemberName:name},classList:{add(){}}})
  let players=[player('Maestro')]
  h.live.contentTarget.querySelectorAll=selector=>selector==='[data-arena-member-key]'?players:[]
  h.live.presentPlayers();assert.equal(h.live.readyNoticeTarget.textContent,'')
  players.push(player('Sabiá'));h.live.presentPlayers();assert.equal(h.live.readyNoticeTarget.textContent,'Sabiá está pronto!')
  h.live.presentPlayers();assert.equal(h.live.readyNoticeTarget.textContent,'Sabiá está pronto!')
  players=[players[0]];h.live.presentPlayers();assert.equal(h.live.readyNoticeTarget.textContent,'')
  h.dataset.phase='question';h.live.presentPlayers();assert.equal(h.live.readyNoticeTarget.textContent,'')
  h.live.disconnect()
})

test('podium reveal continues across fragments and reduced motion shows every place immediately',()=>{
  const h=harness(), properties=[],classes=[]
  const panel={style:{setProperty:(key,value)=>properties.push([key,value])},classList:{add:value=>classes.push(value),remove:value=>classes.push(`remove:${value}`)}}
  const original=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=selector=>selector==='[data-arena-celebration]'?panel:original(selector)
  h.dataset.phase='podium';h.dataset.phaseStartedAt='game-finished'
  h.live.adoptState()
  const start=h.live.podiumStartedAt
  h.live.podiumStartedAt=start-1500
  h.live.adoptState()
  assert.equal(h.live.podiumStartedAt,start-1500)
  assert.ok(parseInt(properties.at(-1)[1])<=-1500)
  h.live.reducedMotion=()=>true;h.live.presentPodium()
  assert.equal(classes.at(-1),'remove:is-celebrating')
  assert.equal(h.live.shouldSettle({departed:true,state:'live',experience:'party',phase:'question',participant_count:1,round:{answered_count:1}}),false)
  h.live.disconnect()
})

test('visible host toolbar retains command focus without a disclosure open property',async()=>{
  const h=harness([{ok:true,text:async()=>'<section>updated controls</section>'}]);let focusCount=0
  const pause={dataset:{arenaCommand:'pause'},focus(){focusCount++}}
  const toolbar={contains:element=>element===pause,querySelector:()=>pause}
  const original=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=selector=>selector==='.arena-director'?toolbar:original(selector)
  h.dataset.phase='question';h.live.adoptState();h.document.activeElement=pause
  await h.live.refreshContent();assert.equal(focusCount,1);h.live.disconnect()
})

test('confirmation opens before restoring the focused finish button after a peer event',async()=>{
  const h=harness([{ok:true,text:async()=>'<nav>peer answered</nav>'}]);let focused=0,opened=false
  const confirm={dataset:{arenaCommand:'finish',arenaPersistentAction:'confirm'},closest:()=>({dataset:{arenaPersistentControl:'finish'}}),focus(){assert.equal(opened,true);focused++}}
  const old={open:true,dataset:{arenaPersistentControl:'finish'}}
  const replacement={set open(value){opened=value},querySelector:()=>confirm}
  const toolbar={contains:element=>element===confirm,querySelector:()=>confirm}
  const original=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=selector=>selector==='.arena-director'?toolbar:selector.startsWith('[data-arena-persistent-control=')?replacement:original(selector)
  h.live.contentTarget.querySelectorAll=selector=>selector==='[data-arena-persistent-control]'?[old]:[]
  h.dataset.phase='question';h.live.adoptState();h.document.activeElement=confirm
  await h.live.refreshContent();assert.equal(focused,1);h.live.disconnect()
})
test('listening waits for all receipts before settlement and supports a presenter countdown', () => {
  const h = harness()
  assert.equal(h.live.shouldSettle({ state:'live',phase:'listening',round:{playback:{ready_count:1,required_count:2}} }), false)
  assert.equal(h.live.shouldSettle({ state:'live',phase:'listening',round:{playback:{ready_count:2,required_count:2}} }), true)
  assert.equal(h.live.shouldSettle({ state:'live',phase:'listening',round:{playback:{ready_count:0,required_count:0}} }), false)
  assert.equal(h.live.shouldSettle({ state:'paused',phase:'listening',round:{playback:{ready_count:2,required_count:2}} }), false)
  assert.equal(h.live.shouldSettle({ state:'live',experience:'facilitated',phase:'countdown',next_transition_at:new Date(Date.now()-1000).toISOString(),round:{state:'ready'} }), true)
  h.live.disconnect()
})
test('skipping the ceremony is local and persists through peer refreshes', () => {
  const h = harness(); const removed=[]
  const panel={style:{setProperty(){}},classList:{remove:c=>removed.push(c),add(){}}}
  const old=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=s=>s==='[data-arena-celebration]'?panel:old(s)
  h.dataset.phase='podium'; h.dataset.phaseStartedAt='same-game'
  h.live.adoptState();h.live.skipPodium();h.live.adoptState()
  assert.equal(h.live.podiumSkipped,true);assert.equal(h.requests.length,0);assert.ok(removed.includes('is-celebrating'))
  h.live.disconnect()
})
test('the audio island is never replaced for a peer receipt in the same round generation',()=>{
  const h=harness();let writes=0
  h.live.hasAudioTarget=true;h.live.audioTarget={hidden:true,set innerHTML(v){writes++}}
  const template={dataset:{arenaAudioTemplate:'round:1'},innerHTML:'player'}
  const old=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=s=>s==='[data-arena-audio-template]'?template:old(s)
  h.live.syncAudio();h.live.syncAudio();assert.equal(writes,1)
  template.dataset.arenaAudioTemplate='round:2';h.live.syncAudio();assert.equal(writes,2)
  h.live.disconnect()
})
test('sound preparation and ceremony come into view once without repeated scrolling on peer updates',()=>{
 for (const phase of ['audio_check', 'podium']) {
  const h=harness(),scrolls=[]
  const panel={classList:{add(){}},scrollIntoView:opts=>scrolls.push(opts),querySelector:()=>null}
  const old=h.live.contentTarget.querySelector
  h.live.contentTarget.querySelector=s=>s==='[data-arena-phase-panel]'?panel:old(s)
  h.dataset.phase=phase;h.dataset.phaseStartedAt='new-phase'
  h.live.adoptState();h.live.adoptState();assert.equal(scrolls.length,1);assert.equal(scrolls[0].block,'start')
  h.live.disconnect()
 }
})
test('score copy confirms the result instead of calling it an invitation code',async()=>{
  const h=harness();h.live.hasCopyStatusTarget=true;h.live.copyStatusTarget={textContent:''}
  await h.live.copy({currentTarget:{dataset:{copyText:'Fiz 900 pontos'},textContent:'Copiar resultado'}})
  assert.match(h.live.copyStatusTarget.textContent,/Resultado copiado/);h.live.disconnect()
})

test('scheduled listening advances by the server deadline even when a player never clicks',()=>{
 const h=harness();h.live.clockOffset=0
 const snapshot={state:'live',phase:'listening',round:{playback:{policy:'sequence-v1',ready_count:0,required_count:40}},next_transition_at:new Date(Date.now()-1).toISOString()}
 assert.equal(h.live.shouldSettle(snapshot),true)
 snapshot.next_transition_at=new Date(Date.now()+30000).toISOString();assert.equal(h.live.shouldSettle(snapshot),false)
 h.live.disconnect()
})

test('audio preparation starts early only for all-ready, otherwise only at its server deadline',()=>{
 const h=harness();h.live.clockOffset=0
 const s={state:'lobby_locked',phase:'audio_check',participant_count:2,audio_check:{all_ready:false},next_transition_at:new Date(Date.now()+45000).toISOString()}
 assert.equal(h.live.shouldSettle(s),false)
 s.audio_check.all_ready=true;assert.equal(h.live.shouldSettle(s),true)
 s.audio_check.all_ready=false;s.next_transition_at=new Date(Date.now()-1).toISOString();assert.equal(h.live.shouldSettle(s),true)
 s.next_transition_at=new Date(Date.now()+45000).toISOString();s.state='cancelled';assert.equal(h.live.shouldSettle(s),false)
 h.live.disconnect()
})
test('preparation readiness acknowledges only its own permission and token, never another player',async()=>{
 const h=harness([{ok:true},{ok:true,text:async()=>'<div>audio-ready</div>'}])
 h.dataset.phase='audio_check';h.dataset.audioCheckNeedsActivation='true';h.dataset.audioCheckOwnReady='false';h.dataset.audioCheckId='check-fixture'
 h.live.audioReadyUrlValue='/audio-ready';h.live.audioPermissionReady=()=>true
 await h.live.syncAudioCheck();h.dataset.audioCheckOwnReady='true';await h.live.syncAudioCheck()
 assert.equal(h.requests.filter(r=>r.options.method==='POST').length,1)
 assert.deepEqual(JSON.parse(h.requests[0].options.body),{check_id:'check-fixture',ready:true})
 h.live.disconnect()
})
test('reload without an unlocked context withdraws previous readiness before preparation closes',async()=>{
 const h=harness([{ok:true},{ok:true,text:async()=>'<div>audio-pending</div>'}])
 Object.assign(h.dataset,{phase:'audio_check',audioCheckNeedsActivation:'true',audioCheckOwnReady:'true',audioCheckId:'check-fixture'})
 h.live.audioReadyUrlValue='/audio-ready';h.live.audioPermissionReady=()=>false
 await h.live.syncAudioCheck()
 assert.deepEqual(JSON.parse(h.requests[0].options.body),{check_id:'check-fixture',ready:false})
 h.live.disconnect()
})
test('an unactivated player never submits readiness or advances preparation locally',async()=>{
 const h=harness();Object.assign(h.dataset,{phase:'audio_check',audioCheckNeedsActivation:'true',audioCheckOwnReady:'false',audioCheckId:'check-fixture'})
 h.live.audioPermissionReady=()=>false;await h.live.syncAudioCheck();assert.equal(h.requests.length,0);h.live.disconnect()
})

test('server revocation does not prevent reconfirming a still-unlocked device',async()=>{
 const h=harness([{ok:true},{ok:true,text:async()=>'<div>ready</div>'},{ok:true},{ok:true,text:async()=>'<div>ready again</div>'}])
 Object.assign(h.dataset,{phase:'audio_check',audioCheckNeedsActivation:'true',audioCheckOwnReady:'false',audioCheckId:'check-fixture'})
 h.live.audioReadyUrlValue='/audio-ready';h.live.audioPermissionReady=()=>true
 await h.live.syncAudioCheck()
 h.dataset.audioCheckOwnReady='true';await h.live.syncAudioCheck()
 h.dataset.audioCheckOwnReady='false';await h.live.syncAudioCheck()
 assert.equal(h.requests.filter(r=>r.options.method==='POST').length,2);h.live.disconnect()
})
test('ack failure remains visible through polling and the next poll retries',async()=>{
 const snapshot={state:'lobby_locked',phase:'audio_check',participant_count:2,sequence:1,version:2,server_now:new Date().toISOString(),next_transition_at:new Date(Date.now()+45000).toISOString(),audio_check:{all_ready:false}}
 const h=harness([{ok:true,json:async()=>snapshot},{ok:false},{ok:true,json:async()=>snapshot},{ok:true},{ok:true,text:async()=>'<div>ready</div>'}])
 Object.assign(h.dataset,{phase:'audio_check',audioCheckNeedsActivation:'true',audioCheckOwnReady:'false',audioCheckId:'check-fixture'})
 h.live.audioReadyUrlValue='/audio-ready';h.live.audioPermissionReady=()=>true
 await h.live.poll();assert.match(h.live.connectionTarget.textContent,/confirmar seu áudio/)
 await h.live.poll();assert.equal(h.live.connectionTarget.textContent,'');h.live.disconnect()
})
