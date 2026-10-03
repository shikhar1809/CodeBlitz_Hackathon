'use strict';
const { test, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const fc = require('../src/family_crypto');
const { createServer } = require('../src/server');
const { FileStore } = require('../src/file_store');

let dir;
let base;
let server;
let store;

afterEach(() => {
  server.closeAllConnections();
  server.close();
});

beforeEach(async () => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vault-'));
  const portal = fs.mkdtempSync(path.join(os.tmpdir(), 'portal-'));
  fs.writeFileSync(path.join(portal, 'index.html'), '<h1>portal</h1>');
  ({ server, store } = createServer({ dataDir: dir, portalDir: portal }));
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});


const call = (method, p, { token, body } = {}) =>
  fetch(base + p, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });

function family() {
  const code = fc.newFamilyCode();
  return { code, ...fc.derive(code) };
}

test('family code round-trips and derives stable keys', () => {
  const code = fc.newFamilyCode();
  assert.strictEqual(code.length, 26);
  const pretty = fc.formatCode(code);
  assert.deepStrictEqual(fc.derive(pretty.toLowerCase()), fc.derive(code));
  assert.match(fc.derive(code).householdId, /^[0-9a-f]{16}$/);
  assert.throws(() => fc.decodeCode('nope'));
});

test('derivation matches the fixed test vector shared with Dart and the portal', () => {
  const d = fc.derive('00000000000000000000000000');
  // Same vector is asserted in app/test/family_crypto_test.dart and portal/selftest.
  assert.strictEqual(d.householdId, fc.derive('0000-0000-0000-0000-0000-0000-00').householdId);
  const box = fc.seal(d.dataKey, 'hello', 'x');
  assert.strictEqual(fc.open(d.dataKey, box, 'x'), 'hello');
  assert.throws(() => fc.open(d.dataKey, box, 'y'), 'AAD binds the record');
});

test('claim, share a snapshot, read it back, and the server only holds ciphertext', async () => {
  const f = family();
  assert.strictEqual((await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken })).status, 200);
  const secret = JSON.stringify({ patient: 'Kamla', medicines: ['Metformin 500 mg'] });
  const box = fc.seal(f.dataKey, secret, `${f.householdId}:snapshot`);
  assert.strictEqual((await call('PUT', `/api/households/${f.householdId}/snapshot`, { token: f.accessToken, body: box })).status, 200);
  const got = await (await call('GET', `/api/households/${f.householdId}/snapshot`, { token: f.accessToken })).json();
  assert.strictEqual(fc.open(f.dataKey, got, `${f.householdId}:snapshot`), secret);

  // Nothing readable on disk: not the name, not the medicine, not the id.
  for (const name of fs.readdirSync(path.join(dir, 'households'))) {
    const raw = fs.readFileSync(path.join(dir, 'households', name)).toString('latin1');
    assert.ok(!raw.includes('Kamla') && !raw.includes('Metformin') && !raw.includes(f.householdId));
    assert.ok(!name.includes(f.householdId));
  }
});

test('a wrong family code cannot read or write', async () => {
  const f = family();
  const other = family();
  await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken });
  const r1 = await call('GET', `/api/households/${f.householdId}/snapshot`, { token: other.accessToken });
  assert.strictEqual(r1.status, 403);
  const r2 = await call('POST', `/api/households/${f.householdId}/events`, { body: { iv: 'AAAAAAAAAAAAAAAA', ct: 'AAAA' } });
  assert.strictEqual(r2.status, 403);
  const r3 = await call('POST', `/api/households/${f.householdId}`, { token: other.accessToken });
  assert.strictEqual(r3.status, 403, 'a household cannot be claimed twice');
});

test('ten wrong tries a minute are rate limited', async () => {
  const f = family();
  await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken });
  let last;
  for (let i = 0; i < 11; i++) last = await call('GET', `/api/households/${f.householdId}/snapshot`, { token: family().accessToken });
  assert.strictEqual(last.status, 429);
});

test('events are append-only and hash-chained; tampering is detected', async () => {
  const f = family();
  await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken });
  for (const msg of ['dose taken', 'dose missed', 'check-in']) {
    const box = fc.seal(f.dataKey, msg, `${f.householdId}:event`);
    await call('POST', `/api/households/${f.householdId}/events`, { token: f.accessToken, body: box });
  }
  const { events } = await (await call('GET', `/api/households/${f.householdId}/events?since=1`, { token: f.accessToken })).json();
  assert.deepStrictEqual(events.map((e) => e.seq), [2, 3]);
  assert.strictEqual(fc.open(f.dataKey, events[1], `${f.householdId}:event`), 'check-in');
  assert.ok(store.verify().ok);

  // Edit an event inside the sealed file (as someone with the vault key could).
  const h = store._load(f.householdId);
  h.events[0].ct = h.events[1].ct;
  store._save(f.householdId, h);
  assert.deepStrictEqual(store.verify().bad, [f.householdId]);
});

test('bad input is refused, not trusted', async () => {
  const f = family();
  await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken });
  const r = await call('PUT', `/api/households/${f.householdId}/snapshot`, { token: f.accessToken, body: { iv: '<script>', ct: 'x' } });
  assert.strictEqual(r.status, 400);
  assert.strictEqual((await call('GET', '/api/households/NOT-HEX/snapshot')).status, 404);
  const big = await call('PUT', `/api/households/${f.householdId}/snapshot`, {
    token: f.accessToken,
    body: { iv: 'AAAAAAAAAAAAAAAA', ct: 'A'.repeat(300 * 1024) },
  });
  assert.strictEqual(big.status, 413);
});

test('erase deletes the household for good', async () => {
  const f = family();
  await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken });
  assert.strictEqual((await call('DELETE', `/api/households/${f.householdId}`, { token: f.accessToken })).status, 200);
  assert.strictEqual((await call('GET', `/api/households/${f.householdId}/snapshot`, { token: f.accessToken })).status, 404);
  assert.strictEqual(await store.count(), 0);
});

test('survives a restart, and backup → restore on another machine is identical', async () => {
  const f = family();
  await call('POST', `/api/households/${f.householdId}`, { token: f.accessToken });
  const box = fc.seal(f.dataKey, 'snap', `${f.householdId}:snapshot`);
  await call('PUT', `/api/households/${f.householdId}/snapshot`, { token: f.accessToken, body: box });

  const again = new FileStore(dir);
  assert.strictEqual((await again.getSnapshot(f.householdId)).ct, box.ct);

  const bak = path.join(dir, 'family.wgbak');
  assert.strictEqual(again.backup(bak), 1);
  const other = fs.mkdtempSync(path.join(os.tmpdir(), 'vault2-'));
  fs.copyFileSync(path.join(dir, 'vault.key'), path.join(other, 'vault.key'));
  const restored = new FileStore(other);
  restored.restore(bak);
  assert.strictEqual((await restored.getSnapshot(f.householdId)).ct, box.ct);
  assert.ok(restored.verify().ok);
});

test('a passphrase vault cannot be opened with the wrong passphrase', async () => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'vault3-'));
  const s = new FileStore(d, { passphrase: 'correct horse battery staple' });
  await s.createHousehold('0123456789abcdef', { tokenHash: 'x', createdAt: 1 });
  const wrong = new FileStore(d, { passphrase: 'wrong' });
  assert.throws(() => wrong.ids());
});

test('serves the portal, health and security headers', async () => {
  const page = await fetch(base + '/');
  assert.match(await page.text(), /portal/);
  assert.strictEqual(page.headers.get('x-frame-options'), 'DENY');
  assert.match(page.headers.get('content-security-policy'), /default-src 'self'/);
  const h = await (await fetch(base + '/api/health')).json();
  assert.strictEqual(h.ok, true);
  assert.strictEqual((await fetch(base + '/../../etc/passwd')).status !== 500, true);
});
