const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs'),vm=require('node:vm')
const strip=p=>fs.readFileSync(p,'utf8').replace(/^import[^\n]*\n/gm,'')
function harness(width=1440,height=900){
 const document={activeElement:{}},window={innerWidth:width,innerHeight:height},listeners=new Map()
 const parent=strip('app/javascript/controllers/practice_switcher_controller.js').replace('export default class extends Controller','class PracticeSwitcherController extends Controller')
 const child=strip('app/javascript/controllers/account_menu_controller.js').replace('export default class extends PracticeSwitcherController','class AccountMenu extends PracticeSwitcherController')
 const Menu=vm.runInNewContext(`${parent}\n${child}\nAccountMenu`,{Controller:class{},document,window})
 const p=new Menu(),sidebar={addEventListener:(key,fn)=>listeners.set(key,fn),removeEventListener:key=>listeners.delete(key)}
 let focus=0,rect={top:800,bottom:864,left:16,width:240},inert=false
 p.element={open:false,closest:()=>sidebar,contains:target=>target===document.activeElement}
 p.summaryTarget={setAttribute(){},focus(){focus++},closest:()=>inert?{}:null,getBoundingClientRect:()=>rect}
 p.panelTarget={style:{},contains:()=>true}
 p.connect()
 return {p,listeners,focus:()=>focus,setRect:r=>rect=r,setInert:()=>inert=true}
}
test('profile panel fits the desktop rail and opens above the footer',()=>{
 const h=harness();h.p.element.open=true;h.p.sync();const s=h.p.panelTarget.style
 assert.equal(s.width,'380px');assert.equal(s.left,'16px');assert.equal(s.bottom,'108px');assert.equal(s.top,'auto')
 h.p.viewportChanged();assert.equal(h.p.element.open,false);assert.equal(h.focus(),1)
})
test('mobile clamps panel to viewport and sidebar scroll closes without leaving focus hidden',()=>{
 const h=harness(320,640);h.setRect({top:570,bottom:620,left:240,width:64});h.p.element.open=true;h.p.sync()
 assert.equal(h.p.panelTarget.style.width,'288px');assert.equal(h.p.panelTarget.style.left,'16px')
 h.listeners.get('scroll')();assert.equal(h.p.element.open,false);assert.equal(h.focus(),1)
 h.setInert();h.p.element.open=true;h.p.viewportChanged();assert.equal(h.focus(),1)
 h.p.disconnect();assert.equal(h.listeners.size,0)
})
