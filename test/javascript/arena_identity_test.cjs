const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs'), vm = require('node:vm')
const source = fs.readFileSync('app/javascript/controllers/arena_identity_controller.js','utf8').replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class Identity extends Controller')
function harness(chosen=false) {
  const Identity=vm.runInNewContext(`${source}\nIdentity`,{Controller:class {}})
  const drawing={cloneNode:()=>({drawing:true})}
  const selected={parentElement:{querySelector:()=>drawing},focus(){this.focused=true}}
  let selection=chosen?selected:null
  const identity=new Identity()
  identity.charactersTarget={querySelector:()=>selection}
  identity.nicknameTarget={value:'Sabiá',focus(){this.focused=true}}
  identity.profileTarget={};identity.previewTarget={replaceChildren(...children){this.children=children}}
  const required={required:true,dataset:{}}
  identity.settingsTarget={querySelectorAll:()=>[required]}
  identity.confirmTarget={};identity.advanceTarget={};identity.backTarget={};identity.stepLabelTarget={}
  identity.connect()
  return {identity,selected,required,choose(){selection=selected;identity.choose()}}
}
test('character choice and continue precede nickname and the final confirm; preview never sends a request',()=>{
  const h=harness();let prevented=0
  assert.equal(h.identity.profileTarget.hidden,true)
  assert.equal(h.identity.confirmTarget.hidden,true)
  assert.equal(h.identity.advanceTarget.disabled,true)
  h.identity.next();assert.equal(h.identity.confirmTarget.hidden,true)
  h.choose();assert.equal(h.identity.advanceTarget.disabled,false)
  assert.equal(h.identity.confirmTarget.hidden,true)
  h.identity.submit({preventDefault(){prevented++}})
  assert.equal(prevented,1)
  assert.equal(h.identity.profileTarget.hidden,false)
  assert.equal(h.identity.nicknameTarget.focused,true)
  assert.equal(h.required.required,true)
  h.identity.submit({preventDefault(){prevented++}});assert.equal(prevented,1)
})
test('returning to characters preserves nickname and restored identity reopens confirmation after an error',()=>{
  const h=harness(true)
  assert.equal(h.identity.confirmTarget.hidden,false)
  h.identity.back()
  assert.equal(h.identity.confirmTarget.hidden,true)
  assert.equal(h.identity.nicknameTarget.value,'Sabiá')
  assert.equal(h.selected.focused,true)
  h.identity.next()
  assert.equal(h.identity.nicknameTarget.value,'Sabiá')
})
