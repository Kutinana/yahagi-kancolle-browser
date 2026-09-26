// Run with: node --test tool/test_game_mouse_wheel_script.cjs
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname,
  '../android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameMouseWheelScript.kt'), 'utf8')
  .split('"""')[1];

function frame(pathname = '/kcs2/index.php') {
  const messages = [], events = [], listeners = {};
  let mutation;
  const canvas = {
    isConnected: true,
    getBoundingClientRect: () => ({left: 10, top: 20, width: 1200, height: 720}),
    dispatchEvent: event => { events.push(event); return false; },
  };
  const bridge = {postMessage: data => messages.push(JSON.parse(data))};
  const document = {hidden: false, querySelector: () => canvas};
  const window = {
    YahagiMouseWheel: bridge,
    addEventListener: (name, handler) => {listeners[name] = handler;},
  };
  const context = vm.createContext({document, window, location: {pathname},
    MutationObserver: class { constructor(handler) {mutation = handler;} observe() {} },
    WheelEvent: class { constructor(type, options) {this.type = type; Object.assign(this, options);} },
  });
  vm.runInContext(source, context, {timeout: 1000});
  return {messages, events, bridge, canvas, context, document, listeners,
    mutate: () => mutation(),
    send: (overrides = {}) => bridge.onmessage({data: JSON.stringify({
      token: messages[0]?.token, kind: 'wheel', x: .5, y: .25,
      deltaX: 0, deltaY: 120, ...overrides,
    })}),
  };
}

test('one packet produces one bubbling wheel at the game canvas', () => {
  const f = frame();
  f.send();
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].type, 'wheel');
  assert.equal(f.events[0].deltaY, 120);
  assert.equal(f.events[0].clientX, 610);
  assert.equal(f.events[0].clientY, 200);
  assert.equal(f.events[0].bubbles, true);
  assert.equal(f.events[0].cancelable, true);
  f.send({deltaY: -120});
  assert.equal(f.events[1].deltaY, -120);
});

test('does not install twice or multiply wheel events', () => {
  const f = frame();
  vm.runInContext(source, f.context, {timeout: 1000});
  assert.equal(f.messages.length, 1);
  f.send();
  assert.equal(f.events.length, 1);
});

test('outer DMM/gadget documents cannot receive game wheels', () => {
  const f = frame('/gadget_html5/');
  assert.equal(f.messages.length, 0);
  f.send();
  assert.equal(f.events.length, 0);
});

test('ignores old document tokens, invalid input and hidden/detached games', () => {
  const f = frame();
  for (const data of [{token: 'old'}, {x: -1}, {x: 1}, {y: 1},
    {deltaY: 0}, {deltaY: null}, {deltaY: '120'}, {kind: 'click'}]) f.send(data);
  f.bridge.onmessage({data: 'not json'});
  f.document.hidden = true;
  f.send();
  f.document.hidden = false;
  f.canvas.isConnected = false;
  f.send();
  f.mutate();
  assert.equal(f.events.length, 0);
  assert.equal(f.messages.at(-1).available, false);
});

test('pagehide withdraws the old frame and pageshow restores availability', () => {
  const f = frame();
  f.listeners.pagehide();
  assert.equal(f.messages.at(-1).available, false);
  f.listeners.pageshow();
  assert.equal(f.messages.at(-1).available, true);
});
