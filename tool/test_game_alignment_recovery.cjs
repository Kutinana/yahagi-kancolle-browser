const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../lib/src/browser/game_page_alignment_script.dart'), 'utf8').split("r'''")[1].split("''';")[0];
function page(hostname = 'play.games.dmm.com', pathname = '/game/kancolle') {
  const elements = new Map();
  const messages = [];
  let observer;
  let visible = true;
  const listeners = new Map();
  const on = (name, fn) => { if (!listeners.has(name)) listeners.set(name, new Set()); listeners.get(name).add(fn); };
  const off = (name, fn) => listeners.get(name)?.delete(fn);
  const element = () => ({isConnected: true, style: {removeProperty() {}},
    getBoundingClientRect: () => ({width:1200,height:720}), setAttribute() {}, removeAttribute() {},
    remove() {}, contentWindow: {scrollTo() {}}});
  elements.set('game_frame', element());
  const context = {location: {hostname, pathname}, getComputedStyle: () => ({display:'block',visibility:'visible'}),
    document: {readyState:'complete', documentElement: {}, body:{},
      head: {appendChild(e) {elements.set(e.id,e);}}, createElement: element,
      getElementById: id => elements.get(id), querySelector: () => null,
      querySelectorAll: s => s === '#game_frame, #game-container' && visible ? [elements.get('game_frame')] : []},
    MutationObserver: class {constructor(cb) {observer=cb;} disconnect() {} observe() {}},
    window: {scrollTo() {}, addEventListener: on, removeEventListener: off,
      YahagiPresentation: {postMessage: m => messages.push(m)}}};
  vm.createContext(context);
  return {messages, listeners, loading: value => {context.document.readyState = value ? 'loading' : 'complete';},
    show: value => {visible = value;}, run: () => vm.runInContext(source, context), mutate: () => observer?.()};
}
const game = page();
assert.equal(game.run(), 'game');
const before = game.messages.length;
assert.equal(game.run(), 'game');
assert.equal(game.messages.length, before + 1, 'Explicit fit must reach Android even when game state is unchanged');
assert.equal(game.messages.at(-1), 'game-fit');
const fitted = game.messages.length;
for (let i=0;i<10;i++) game.mutate();
assert.equal(game.messages.length, fitted, 'DOM mutations must not create a refit loop');
const login = page('accounts.dmm.com', '/login');
assert.equal(login.run(), 'web');
assert.equal(login.run(), 'web');
assert.deepEqual(login.messages, ['web'], 'Login pages must not request game scaling');
const delayed = page();
delayed.show(false);
assert.equal(delayed.run(), 'pending');
delayed.show(true);
delayed.mutate();
assert.equal(delayed.messages.at(-1), 'game', 'Late game frame must bind native scaling');
delayed.run();
assert.equal(delayed.messages.at(-1), 'game-fit', 'Page finish must force final sizing after early binding');
console.log('Alignment recovery: repeated fit, mutation deduplication, login isolation passed');
for (const [host, url] of [
  ['play.games.dmm.com', '/game/kancolle'],
  ['www.dmm.com', '/netgame/social/-/gadgets/=/app_id=854854/'],
  ['osapi.dmm.com', '/gadgets/ifr'],
]) {
  const loading = page(host, url);
  loading.loading(true);
  for (let cycle = 0; cycle < 200; cycle++) {
    loading.run();
    for (let mutation=0;mutation<10;mutation++) loading.mutate();
    assert.equal(loading.listeners.get('load')?.size, 1, 'Repeated fits during slow loading must not accumulate load listeners');
    assert.equal(loading.listeners.get('scroll')?.size, 1);
  }
  assert.equal(loading.messages.length, 200, 'Mutations must not amplify explicit fit requests');
  loading.loading(false);
  loading.show(false);
  loading.mutate();
  assert.equal(loading.messages.at(-1), 'pending');
  loading.show(true);
  loading.mutate();
  assert.equal(loading.messages.at(-1), 'game');
}
console.log('Slow-load stress: 600 explicit fits and 6000 DOM changes passed');
