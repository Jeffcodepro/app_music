const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')

function themeHarness(saved = 'system') {
  const listeners = new Set(), storageListeners = new Set()
  const media = { matches: false, addEventListener(_, fn) { listeners.add(fn) }, removeEventListener(_, fn) { listeners.delete(fn) } }
  const document = { documentElement: { dataset: {}, style: {} } }
  const storage = { getItem() { return saved }, setItem(_, value) { saved = value } }
  const window = { matchMedia: () => media, addEventListener(_, fn) { storageListeners.add(fn) }, removeEventListener(_, fn) { storageListeners.delete(fn) } }
  const source = fs.readFileSync('app/javascript/controllers/theme_controller.js', 'utf8').replace(/^import .*\n/, '').replace('export default class', 'class Theme') + '\nTheme'
  const Theme = vm.runInNewContext(source, { Controller: class {}, document, window, localStorage: storage })
  const target = new Theme()
  target.selectTargets = [{ value: '' }, { value: '' }]
  target.choiceTargets = ['light','dark','system'].map(value=>({value,attributes:{},setAttribute(key,value){this.attributes[key]=value}}))
  target.toggleTargets = [{attributes:{},setAttribute(key,value){this.attributes[key]=value}}]
  target.connect()
  return { target, document, media, listeners, storageListeners, storage }
}

test('system theme responds to OS changes; an explicit preference takes priority', () => {
  const h = themeHarness()
  assert.equal(h.document.documentElement.dataset.theme, 'light')
  h.media.matches = true
  h.listeners.forEach(fn => fn())
  assert.equal(h.document.documentElement.dataset.theme, 'dark')
  h.target.change({ target: { value: 'light' } })
  h.listeners.forEach(fn => fn())
  assert.equal(h.document.documentElement.dataset.theme, 'light')
  assert(h.target.selectTargets.every(select => select.value === 'light'))
})

test('theme storage events synchronize selectors and disconnect releases every listener', () => {
  const h = themeHarness('dark')
  h.storage.setItem('app_music_theme', 'light')
  h.storageListeners.forEach(fn => fn())
  assert.equal(h.document.documentElement.dataset.theme, 'light')
  assert(h.target.selectTargets.every(select => select.value === 'light'))
  h.target.disconnect()
  assert.equal(h.listeners.size, 0)
  assert.equal(h.storageListeners.size, 0)
  h.target.connect()
  assert.equal(h.listeners.size, 1)
  assert.equal(h.storageListeners.size, 1)
})

test('blocked storage and corrupt preferences do not prevent rendering or changing theme', () => {
  const h = themeHarness('invalid')
  assert.equal(h.document.documentElement.dataset.theme, 'light')
  h.storage.getItem = () => { throw Error('unavailable') }
  h.storage.setItem = () => { throw Error('unavailable') }
  h.target.apply()
  h.target.change({ target: { value: 'dark' } })
  assert.equal(h.document.documentElement.dataset.theme, 'dark')
  h.target.change({ target: { value: 'malicious' } })
  assert.equal(h.document.documentElement.dataset.theme, 'dark')
})

test('head bootstrap resolves the theme before page rendering even when storage is blocked', () => {
  const source = fs.readFileSync('app/views/shared/_theme_boot.html.erb', 'utf8').replace('<script>', '').replace('</script>', '')
  const document = { documentElement: { dataset: {}, style: {} } }
  vm.runInNewContext(source, { document, window: { matchMedia: () => ({ matches: true }) }, localStorage: { getItem() { throw Error('blocked') } } })
  assert.equal(document.documentElement.dataset.theme, 'dark')
  assert.equal(document.documentElement.style.colorScheme, 'dark')
  assert.equal(document.documentElement.dataset.bsTheme, 'dark')
  assert.equal(document.documentElement.dataset.themePreference, 'system')
})

test('Bootstrap and selectors follow the same resolved theme', () => {
  const h = themeHarness('dark')
  assert.equal(h.document.documentElement.dataset.bsTheme, 'dark')
  h.target.change({ target: { value: 'light' } })
  assert.equal(h.document.documentElement.dataset.bsTheme, 'light')
  assert.equal(h.document.documentElement.dataset.themePreference, 'light')
})

test('failed persistence does not discard the explicit selection on OS or Turbo updates', () => {
  const h = themeHarness('light')
  h.storage.setItem = () => { throw Error('quota exceeded') }
  h.target.change({ target: { value: 'dark' } })
  h.media.matches = false
  h.listeners.forEach(fn => fn())
  h.target.apply({ type: 'turbo:before-render' })
  assert.equal(h.document.documentElement.dataset.theme, 'dark')
  assert(h.target.selectTargets.every(select => select.value === 'dark'))
})

test('new selectors and relevant cross-tab updates synchronize without unrelated storage changes', () => {
  const h = themeHarness('dark')
  const added = { value: 'system' }
  h.target.selectTargetConnected(added)
  assert.equal(added.value, 'dark')
  h.storage.setItem('app_music_theme', 'light')
  h.storageListeners.forEach(fn => fn({ key: 'unrelated' }))
  assert.equal(h.document.documentElement.dataset.theme, 'dark')
  h.storageListeners.forEach(fn => fn({ key: 'app_music_theme' }))
  assert.equal(h.document.documentElement.dataset.theme, 'light')
})

test('icon choices and text selectors stay synchronized across preference and OS changes',()=>{
  const h=themeHarness('dark')
  assert.equal(h.target.choiceTargets.find(c=>c.value==='dark').attributes['aria-pressed'],'true')
  h.target.choose({currentTarget:{value:'system'}})
  h.media.matches=true;h.listeners.forEach(fn=>fn())
  assert.equal(h.document.documentElement.dataset.theme,'dark')
  assert.equal(h.target.choiceTargets.find(c=>c.value==='system').attributes['aria-pressed'],'true')
  assert.equal(h.target.toggleTargets[0].attributes['aria-label'],'Tema da interface: Sistema')
  assert(h.target.selectTargets.every(s=>s.value==='system'))
  const newChoice={value:'system',setAttribute(key,value){this[key]=value}}
  h.target.choiceTargetConnected(newChoice)
  assert.equal(newChoice['aria-pressed'],'true')
})

test('public theme stays light without overwriting the saved authenticated preference',()=>{
 const h=themeHarness('dark');h.target.fixedValue='light';h.target.apply();h.media.matches=true;h.listeners.forEach(fn=>fn())
 assert.equal(h.document.documentElement.dataset.theme,'light')
 assert.equal(h.document.documentElement.dataset.bsTheme,'light')
 assert.equal(h.storage.getItem('app_music_theme'),'dark')
 h.target.disconnect();h.target.fixedValue='';h.target.connect()
 assert.equal(h.document.documentElement.dataset.theme,'dark')
})
