const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm')
const source=fs.readFileSync('app/javascript/controllers/arena_setup_controller.js','utf8').replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class Setup extends Controller')
test('reading hides and disables listening count while every audible area restores its chosen value',()=>{
 const Setup=vm.runInNewContext(`${source}\nSetup`,{Controller:class{}}),s=new Setup()
 s.hasAreaTarget=true;s.areaTarget={value:'leitura'};s.listeningTarget={};s.repetitionsTarget={value:'5'};s.connect()
 assert.equal(s.listeningTarget.hidden,true);assert.equal(s.repetitionsTarget.disabled,true)
 for(const area of ['percepcao','ritmica','harmonia','all']){s.areaTarget.value=area;s.update();assert.equal(s.listeningTarget.hidden,false);assert.equal(s.repetitionsTarget.disabled,false);assert.equal(s.repetitionsTarget.value,'5')}
 s.areaTarget.value='leitura';s.update();assert.equal(s.listeningTarget.hidden,true);assert.equal(s.repetitionsTarget.value,'5')
})

test('ending a room keeps creation settings and uses the protected versioned command',async()=>{
 const requests=[],rows=[{}],button={},status={textContent:''},empty={hidden:true}
 const Setup=vm.runInNewContext(`${source}\nSetup`,{Controller:class{},document:{querySelector:()=>({content:'csrf-fixture'})},FormData:class{constructor(form){this.fields=form.fields}},fetch:async(url,options)=>{requests.push({url,options});return {ok:true}}})
 const s=new Setup()
 let focused=false;s.element={querySelector:()=>({focus:()=>focused=true})}
 s.roomStatusTarget=status;s.emptyRoomsTarget=empty;s.roomTargets=rows
 const form={action:'/app/arena/salas/fixture/comando',dataset:{roomTitle:'Sala antiga'},fields:{command:'finish',version:'12'},querySelector:()=>button,closest:()=>({remove:()=>rows.pop()})}
 await s.finishRoom({preventDefault(){},currentTarget:form})
 assert.equal(requests[0].options.method,'POST');assert.equal(requests[0].options.headers['X-CSRF-Token'],'csrf-fixture')
 assert.equal(requests[0].options.body.fields.version,'12');assert.equal(rows.length,0);assert.equal(empty.hidden,false)
 assert.match(status.textContent,/resultados foram preservados/);assert.equal(button.disabled,false)
 assert.equal(focused,true)
})

test('a failed or conflicting close keeps the room and leaves a recovery message',async()=>{
 const Setup=vm.runInNewContext(`${source}\nSetup`,{Controller:class{},document:{querySelector:()=>({content:'csrf'})},FormData:class{},fetch:async()=>({ok:false,status:409})}),s=new Setup(),button={}
 s.roomStatusTarget={textContent:''};let removed=false
 const form={action:'/command',dataset:{},querySelector:()=>button,closest:()=>({remove:()=>removed=true})}
 await s.finishRoom({preventDefault(){},currentTarget:form})
 assert.equal(removed,false);assert.equal(button.disabled,false);assert.match(s.roomStatusTarget.textContent,/sala pode ter mudado/)
})
