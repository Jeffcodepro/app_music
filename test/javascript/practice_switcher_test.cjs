const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs')
const vm=require('node:vm')
function harness(){
  const source=fs.readFileSync('app/javascript/controllers/practice_switcher_controller.js','utf8').replace(/^import .*\n/,'').replace('export default class','class Switcher')+'\nSwitcher'
  const Switcher=vm.runInNewContext(source,{Controller:class{}}),controller=new Switcher(),attributes={}
  let focused=false
  controller.element={open:false,contains:target=>target==='inside'}
  controller.summaryTarget={setAttribute:(key,value)=>attributes[key]=value,focus:()=>focused=true}
  controller.connect()
  return{controller,attributes,focused:()=>focused}
}
test('Escape closes only an open disclosure and restores summary focus',()=>{
  const h=harness();let prevented=0,stopped=0
  const event={preventDefault:()=>prevented++,stopPropagation:()=>stopped++}
  h.controller.escape(event);assert.equal(prevented,0)
  h.controller.element.open=true;h.controller.sync();assert.equal(h.attributes['aria-expanded'],'true')
  h.controller.escape(event);assert.equal(h.controller.element.open,false);assert.equal(prevented,1);assert.equal(stopped,1);assert(h.focused());assert.equal(h.attributes['aria-expanded'],'false')
})
test('outside click closes without stealing focus; inside interaction stays open',()=>{
  const h=harness();h.controller.element.open=true
  h.controller.outside({target:'inside'});assert(h.controller.element.open)
  h.controller.outside({target:'outside'});assert.equal(h.controller.element.open,false);assert.equal(h.focused(),false)
})
test('navigation and Turbo caching close the disclosure without focus side effects',()=>{
  const h=harness();h.controller.element.open=true
  h.controller.navigate({target:{closest:()=>null}});assert(h.controller.element.open)
  h.controller.navigate({target:{closest:()=>({})}});assert.equal(h.controller.element.open,false)
  h.controller.element.open=true;h.controller.beforeCache();assert.equal(h.controller.element.open,false);assert.equal(h.attributes['aria-expanded'],'false');assert.equal(h.focused(),false)
})
