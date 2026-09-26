const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync(process.argv[2], 'utf8');

function documentFor(sessionId, binary) {
  const messages = [];
  const pendingFetch = [];
  class Xhr {
    open(method, url) { this.responseURL = url; }
    send() {}
    addEventListener(_, listener) { this.listener = listener; }
    finish() {
      this.responseText = '{"api_result":1}';
      this.responseType = '';
      this.status = 200;
      this.listener();
    }
  }
  const context = vm.createContext({
    URL, URLSearchParams, TextEncoder, XMLHttpRequest: Xhr,
    performance: {timeOrigin: sessionId.includes('account-b') ? 2000.5 : 1000.25},
    location: {href: 'https://w01y.kancolle-server.com/kcs2/index.php'},
    fetch: () => new Promise(resolve => pendingFetch.push(resolve)),
    YahagiNativeCapture: { postMessage(value) {
      if (typeof value === 'string') messages.push(JSON.parse(value));
      else {
        const bytes = Buffer.from(value);
        const metadataLength = bytes.readUInt32BE(0);
        messages.push(JSON.parse(bytes.subarray(4, metadataLength + 4).toString()));
      }
    }},
  });
  context.window = context;
  function inject(id) {
    vm.runInContext(script.replaceAll('__YAHAGI_CAPTURE_SESSION_ID__', id)
      .replaceAll('__YAHAGI_BINARY_CAPTURE_ENABLED__', String(binary)), context);
  }
  inject(sessionId);
  return {context, messages, pendingFetch, inject};
}

async function run(binary) {
  const old = documentFor('account-a-login', binary);
  const oldRequest = old.context.fetch('/kcsapi/api_port/port', {method: 'POST'});
  const xhr = new old.context.XMLHttpRequest();
  xhr.open('POST', '/kcsapi/api_get_member/basic');
  xhr.send('api_verno=1');
  const next = documentFor('account-b-login', binary);
  const nextRequest = next.context.fetch('/kcsapi/api_start2/getData', {method: 'POST'});
  const response = {status: 200, clone: () => ({text: async () => '{"api_result":1}'})};
  next.pendingFetch.shift()(response);
  await nextRequest;
  await new Promise(resolve => setImmediate(resolve));
  old.inject('account-b-login');
  old.pendingFetch.shift()(response);
  xhr.finish();
  await oldRequest;
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(next.messages.length, 1);
  assert.equal(old.messages.length, 2);
  assert.equal(next.messages[0].captureSessionId, 'account-b-login');
  assert.ok(old.messages.every(message => message.captureSessionId === 'account-a-login'));
  assert.equal(new Set(old.messages.map(message => message.captureDocumentId)).size, 1);
  assert.notEqual(old.messages[0].captureDocumentId, next.messages[0].captureDocumentId);
  assert.equal(old.messages[0].captureDocumentStartedAtEpochMs, 1000.25);
  assert.equal(next.messages[0].captureDocumentStartedAtEpochMs, 2000.5);
}

run(false).then(() => run(true)).then(() => console.log('capture session fetch/XHR string/binary: passed'))
  .catch(error => { console.error(error); process.exitCode = 1; });
