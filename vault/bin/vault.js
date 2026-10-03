#!/usr/bin/env node
'use strict';
/**
 * winger-vault: run the family's Home Vault on a spare computer.
 *
 *   node bin/vault.js start [--port 8787] [--data ./vault-data]
 *   node bin/vault.js backup <file>      one sealed file with every household
 *   node bin/vault.js restore <file>
 *   node bin/vault.js verify             checks every event chain
 *
 * Set VAULT_PASSPHRASE to derive the at-rest key from a passphrase (scrypt)
 * instead of the generated vault.key file.
 */
const path = require('path');
const { createServer, lanAddresses, VERSION } = require('../src/server');
const { FileStore } = require('../src/file_store');

const args = process.argv.slice(2);
const cmd = args[0] || 'start';
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : def;
};
const dataDir = path.resolve(opt('data', process.env.VAULT_DATA || path.join(__dirname, '..', 'vault-data')));
const passphrase = process.env.VAULT_PASSPHRASE || undefined;

if (cmd === 'start') {
  const port = parseInt(opt('port', process.env.PORT || '8787'), 10);
  const portalDir = path.resolve(opt('portal', path.join(__dirname, '..', '..', 'portal')));
  const { server, store } = createServer({ dataDir, portalDir, passphrase });
  server.listen(port, '0.0.0.0', async () => {
    console.log(`\n  Winger Home Vault ${VERSION}`);
    console.log(`  Data:      ${dataDir} (sealed with ${passphrase ? 'your passphrase' : 'vault.key'})`);
    console.log(`  Families:  ${await store.count()}`);
    console.log('\n  Family portal on this computer:  http://localhost:' + port);
    for (const ip of lanAddresses()) console.log(`  On your home Wi-Fi:              http://${ip}:${port}`);
    console.log('\n  In the Winger app: Settings → Family sync → Home Vault address.');
    console.log('  Keep vault.key safe and back up with: node bin/vault.js backup <file>\n');
  });
} else if (cmd === 'backup' || cmd === 'restore') {
  const file = args[1];
  if (!file) {
    console.error(`usage: vault ${cmd} <file>`);
    process.exit(2);
  }
  const store = new FileStore(dataDir, { passphrase });
  const n = cmd === 'backup' ? store.backup(path.resolve(file)) : store.restore(path.resolve(file));
  console.log(`${cmd === 'backup' ? 'Backed up' : 'Restored'} ${n} household(s).`);
} else if (cmd === 'verify') {
  const r = new FileStore(dataDir, { passphrase }).verify();
  console.log(r.ok ? 'All households intact.' : `Damaged: ${r.bad.join(', ')}`);
  process.exit(r.ok ? 0 : 1);
} else {
  console.error('commands: start | backup <file> | restore <file> | verify');
  process.exit(2);
}
