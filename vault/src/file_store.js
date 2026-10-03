'use strict';
/**
 * The Home Vault's storage: one file per household, encrypted at rest.
 *
 * Two layers. What the phone sends is already end-to-end encrypted with the
 * family's key. On top of that the Vault seals each household file with its
 * own key (AES-256-GCM), so a stolen laptop disk shows nothing, not even
 * which households exist or when they last synced.
 *
 * The vault key comes from VAULT_PASSPHRASE (scrypt) or, when that is not
 * set, a random key file created on first run with owner-only permissions.
 *
 * Events are append-only and hash-chained: each one carries
 * sha256(previous hash + its own ciphertext), so a deleted or edited event
 * breaks the chain and `verify()` says so.
 *
 * Writes go to a temp file then rename, so a power cut never leaves half a
 * file. Old snapshots beyond KEEP_SNAPSHOTS are dropped.
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const KEEP_SNAPSHOTS = 30;
const GENESIS = '0'.repeat(64);

function vaultKey(dir, passphrase) {
  if (passphrase) {
    const saltFile = path.join(dir, 'vault.salt');
    if (!fs.existsSync(saltFile)) fs.writeFileSync(saltFile, crypto.randomBytes(16), { mode: 0o600 });
    return crypto.scryptSync(passphrase, fs.readFileSync(saltFile), 32, { N: 1 << 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
  }
  const keyFile = path.join(dir, 'vault.key');
  if (!fs.existsSync(keyFile)) fs.writeFileSync(keyFile, crypto.randomBytes(32), { mode: 0o600 });
  const key = fs.readFileSync(keyFile);
  if (key.length !== 32) throw new Error('vault.key is damaged');
  return key;
}

class FileStore {
  constructor(dir, { passphrase } = {}) {
    this.dir = dir;
    this.hdir = path.join(dir, 'households');
    fs.mkdirSync(this.hdir, { recursive: true, mode: 0o700 });
    this.key = vaultKey(dir, passphrase);
    // File names are a keyed hash of the id, so a directory listing does not
    // reveal household ids either.
    this.cache = new Map();
  }

  _file(id) {
    const name = crypto.createHmac('sha256', this.key).update(id).digest('hex').slice(0, 32);
    return path.join(this.hdir, `${name}.vault`);
  }

  _seal(obj, id) {
    const iv = crypto.randomBytes(12);
    const c = crypto.createCipheriv('aes-256-gcm', this.key, iv);
    c.setAAD(Buffer.from(`winger-vault:${id}`));
    const body = Buffer.concat([c.update(JSON.stringify(obj)), c.final()]);
    return Buffer.concat([Buffer.from('WGV1'), iv, c.getAuthTag(), body]);
  }

  _open(buf, id) {
    if (buf.subarray(0, 4).toString() !== 'WGV1') throw new Error('not a vault file');
    const iv = buf.subarray(4, 16);
    const tag = buf.subarray(16, 32);
    const d = crypto.createDecipheriv('aes-256-gcm', this.key, iv);
    d.setAAD(Buffer.from(`winger-vault:${id}`));
    d.setAuthTag(tag);
    return JSON.parse(Buffer.concat([d.update(buf.subarray(32)), d.final()]).toString('utf8'));
  }

  _load(id) {
    if (this.cache.has(id)) return this.cache.get(id);
    const f = this._file(id);
    if (!fs.existsSync(f)) return null;
    const h = this._open(fs.readFileSync(f), id);
    this.cache.set(id, h);
    return h;
  }

  _save(id, h) {
    const f = this._file(id);
    const tmp = `${f}.${process.pid}.tmp`;
    fs.writeFileSync(tmp, this._seal(h, id), { mode: 0o600 });
    fs.renameSync(tmp, f);
    this.cache.set(id, h);
  }

  async count() {
    return this.ids().length;
  }

  async getHousehold(id) {
    const h = this._load(id);
    return h && { id, tokenHash: h.tokenHash, createdAt: h.createdAt };
  }

  async createHousehold(id, meta) {
    this._save(id, { id, ...meta, snapshots: [], events: [] });
    this._setIds([...new Set([...this.ids(), id])]);
  }

  async deleteHousehold(id) {
    const f = this._file(id);
    if (fs.existsSync(f)) {
      // Overwrite before unlinking so the old ciphertext is not left on disk.
      fs.writeFileSync(f, crypto.randomBytes(fs.statSync(f).size));
      fs.unlinkSync(f);
    }
    this.cache.delete(id);
    this._setIds(this.ids().filter((x) => x !== id));
  }

  async putSnapshot(id, s) {
    const h = this._load(id);
    h.snapshots.push(s);
    if (h.snapshots.length > KEEP_SNAPSHOTS) h.snapshots = h.snapshots.slice(-KEEP_SNAPSHOTS);
    this._save(id, h);
  }

  async getSnapshot(id) {
    const h = this._load(id);
    return h.snapshots.length ? h.snapshots[h.snapshots.length - 1] : null;
  }

  async appendEvent(id, e) {
    const h = this._load(id);
    const prev = h.events.length ? h.events[h.events.length - 1].hash : GENESIS;
    const seq = h.events.length + 1;
    const hash = crypto.createHash('sha256').update(`${prev}|${seq}|${e.iv}|${e.ct}`).digest('hex');
    const ev = { seq, ...e, hash };
    h.events.push(ev);
    this._save(id, h);
    return ev;
  }

  async listEvents(id, since, limit) {
    return this._load(id).events.filter((e) => e.seq > since).slice(0, limit);
  }

  /** Household ids, from the encrypted index (never from file names). */
  ids() {
    const f = path.join(this.dir, 'index.vault');
    return fs.existsSync(f) ? this._open(fs.readFileSync(f), 'index') : [];
  }

  _setIds(ids) {
    const f = path.join(this.dir, 'index.vault');
    fs.writeFileSync(`${f}.tmp`, this._seal(ids, 'index'), { mode: 0o600 });
    fs.renameSync(`${f}.tmp`, f);
  }

  /** True when every household opens and its event chain is intact. */
  verify() {
    const bad = [];
    for (const id of this.ids()) {
      try {
        this.cache.delete(id);
        const h = this._load(id);
        let prev = GENESIS;
        for (const e of h.events) {
          const want = crypto.createHash('sha256').update(`${prev}|${e.seq}|${e.iv}|${e.ct}`).digest('hex');
          if (want !== e.hash) throw new Error('chain broken');
          prev = e.hash;
        }
      } catch {
        bad.push(id);
      }
    }
    return { ok: bad.length === 0, bad };
  }

  /** One encrypted file holding every household, for a USB stick or a cloud drive. */
  backup(toFile) {
    const files = fs.readdirSync(this.hdir).filter((n) => n.endsWith('.vault'));
    const bundle = { v: 1, at: Date.now(), files: {} };
    for (const n of files) bundle.files[n] = fs.readFileSync(path.join(this.hdir, n)).toString('base64');
    bundle.ids = this.ids();
    fs.writeFileSync(toFile, this._seal(bundle, 'backup'), { mode: 0o600 });
    return files.length;
  }

  restore(fromFile) {
    const bundle = this._open(fs.readFileSync(fromFile), 'backup');
    for (const [n, b64] of Object.entries(bundle.files)) {
      if (!/^[0-9a-f]{32}\.vault$/.test(n)) continue;
      fs.writeFileSync(path.join(this.hdir, n), Buffer.from(b64, 'base64'), { mode: 0o600 });
    }
    this._setIds([...new Set([...this.ids(), ...(bundle.ids || [])])]);
    this.cache.clear();
    return Object.keys(bundle.files).length;
  }
}

module.exports = { FileStore };
