'use strict';
/**
 * The Winger family API. One implementation, two homes: the Home Vault on a
 * laptop at home (FileStore) and the hosted relay on Firebase (FirestoreStore).
 *
 * Everything a household stores is ciphertext made on the patient's phone.
 * The API only checks who may read and write it.
 *
 *   GET    /api/health
 *   POST   /api/households/:id              claim a household (first writer wins)
 *   PUT    /api/households/:id/snapshot     {iv, ct}   the latest family view
 *   GET    /api/households/:id/snapshot
 *   POST   /api/households/:id/events       {iv, ct}   append-only, hash-chained
 *   GET    /api/households/:id/events?since=N
 *   DELETE /api/households/:id              erase everything (the patient's right)
 *
 * Every household route needs `Authorization: Bearer <access token>`; only
 * its SHA-256 is stored. Ten failed tries a minute from one address → 429.
 */
const { sha256 } = require('./family_crypto');

const MAX_BODY = 256 * 1024;
const MAX_FAILS = 10;
const FAIL_WINDOW_MS = 60 * 1000;

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function createApi(store, { now = () => Date.now(), version = '1.0.0', origins = ['*'] } = {}) {
  const fails = new Map(); // ip -> [timestamps]

  function limited(ip) {
    const t = now();
    const recent = (fails.get(ip) || []).filter((x) => t - x < FAIL_WINDOW_MS);
    fails.set(ip, recent);
    return recent.length >= MAX_FAILS;
  }

  function fail(ip) {
    const list = fails.get(ip) || [];
    list.push(now());
    fails.set(ip, list);
  }

  function cors(req, res) {
    const origin = req.headers.origin;
    const allow = origins.includes('*') ? '*' : origins.includes(origin) ? origin : null;
    if (allow) res.setHeader('Access-Control-Allow-Origin', allow);
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Vary', 'Origin');
  }

  function token(req) {
    const h = req.headers.authorization || '';
    const m = /^Bearer\s+([A-Za-z0-9_-]{20,100})$/.exec(h);
    return m ? m[1] : null;
  }

  function box(body) {
    if (!body || typeof body.iv !== 'string' || typeof body.ct !== 'string') {
      throw new ApiError(400, 'expected {iv, ct}');
    }
    if (!/^[A-Za-z0-9+/=]{16,24}$/.test(body.iv) || !/^[A-Za-z0-9+/=]+$/.test(body.ct)) {
      throw new ApiError(400, 'iv and ct must be base64');
    }
    return { iv: body.iv, ct: body.ct };
  }

  async function authorise(req, ip, id) {
    if (limited(ip)) throw new ApiError(429, 'too many tries, wait a minute');
    const t = token(req);
    const h = await store.getHousehold(id);
    if (!h) throw new ApiError(404, 'no such household');
    if (!t || sha256(t) !== h.tokenHash) {
      fail(ip);
      throw new ApiError(403, 'wrong family code');
    }
    return h;
  }

  async function route(req, body, ip) {
    const url = new URL(req.url, 'http://x');
    const path = url.pathname;
    if (req.method === 'GET' && path === '/api/health') {
      return { ok: true, version, households: await store.count() };
    }
    const m = /^\/api\/households\/([0-9a-f]{16})(\/snapshot|\/events)?$/.exec(path);
    if (!m) throw new ApiError(404, 'no such route');
    const [, id, sub] = m;

    if (!sub && req.method === 'POST') {
      if (limited(ip)) throw new ApiError(429, 'too many tries, wait a minute');
      const t = token(req);
      if (!t) throw new ApiError(401, 'missing token');
      const existing = await store.getHousehold(id);
      if (existing) {
        if (existing.tokenHash !== sha256(t)) {
          fail(ip);
          throw new ApiError(403, 'household already claimed');
        }
        return { ok: true, created: false };
      }
      await store.createHousehold(id, { tokenHash: sha256(t), createdAt: now() });
      return { ok: true, created: true };
    }

    await authorise(req, ip, id);
    if (!sub && req.method === 'DELETE') {
      await store.deleteHousehold(id);
      return { ok: true, deleted: true };
    }
    if (sub === '/snapshot' && req.method === 'PUT') {
      const at = now();
      await store.putSnapshot(id, { ...box(body), at });
      return { ok: true, at };
    }
    if (sub === '/snapshot' && req.method === 'GET') {
      const s = await store.getSnapshot(id);
      if (!s) throw new ApiError(404, 'nothing shared yet');
      return s;
    }
    if (sub === '/events' && req.method === 'POST') {
      const e = await store.appendEvent(id, { ...box(body), at: now() });
      return { ok: true, seq: e.seq, hash: e.hash };
    }
    if (sub === '/events' && req.method === 'GET') {
      const since = Math.max(0, parseInt(url.searchParams.get('since') || '0', 10) || 0);
      return { events: await store.listEvents(id, since, 200) };
    }
    throw new ApiError(405, 'method not allowed');
  }

  /** Node http handler. Returns true when it handled the request. */
  return async function handle(req, res) {
    if (!req.url.startsWith('/api/')) return false;
    cors(req, res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    if (req.method === 'OPTIONS') {
      res.statusCode = 204;
      res.end();
      return true;
    }
    const ip = req.headers['x-forwarded-for']?.split(',')[0].trim() || req.socket?.remoteAddress || '?';
    try {
      let body = req.body; // set by Cloud Functions
      if (body === undefined && (req.method === 'POST' || req.method === 'PUT')) body = await readJson(req);
      const out = await route(req, body, ip);
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify(out));
    } catch (e) {
      res.statusCode = e.status || 500;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: e.status ? e.message : 'server error' }));
    }
    return true;
  };
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    // Too large: keep draining (so the 413 can still be sent), but keep nothing.
    req.on('data', (c) => {
      size += c.length;
      if (size <= MAX_BODY) chunks.push(c);
    });
    req.on('end', () => {
      if (size > MAX_BODY) return reject(new ApiError(413, 'too large'));
      if (!chunks.length) return resolve(undefined);
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new ApiError(400, 'bad JSON'));
      }
    });
    req.on('error', reject);
  });
}

module.exports = { createApi, ApiError };
