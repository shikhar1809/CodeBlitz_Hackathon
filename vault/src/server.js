'use strict';
/**
 * Winger Home Vault: the family's medicine records, kept at home.
 *
 * Serves the family portal and the family API on your home network. Data
 * arrives end-to-end encrypted from the patient's phone and is sealed again
 * at rest with the Vault's own key.
 */
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createApi } = require('./api');
const { FileStore } = require('./file_store');

const VERSION = require('../package.json').version;

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.json': 'application/json',
  '.ico': 'image/x-icon',
};

function securityHeaders(res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; connect-src 'self'; frame-ancestors 'none'",
  );
}

function serveStatic(root, req, res) {
  const url = new URL(req.url, 'http://x');
  let p = decodeURIComponent(url.pathname);
  if (p.endsWith('/')) p += 'index.html';
  const file = path.normalize(path.join(root, p));
  if (!file.startsWith(path.normalize(root))) {
    res.statusCode = 400;
    return res.end('bad path');
  }
  const target = fs.existsSync(file) && fs.statSync(file).isFile() ? file : path.join(root, 'index.html');
  res.setHeader('Content-Type', TYPES[path.extname(target)] || 'application/octet-stream');
  res.setHeader('Cache-Control', 'no-cache');
  fs.createReadStream(target).pipe(res);
}

function lanAddresses() {
  const out = [];
  for (const list of Object.values(os.networkInterfaces())) {
    for (const a of list || []) if (a.family === 'IPv4' && !a.internal) out.push(a.address);
  }
  return out;
}

function createServer({ dataDir, portalDir, passphrase, origins } = {}) {
  const store = new FileStore(dataDir, { passphrase });
  const api = createApi(store, { version: VERSION, origins: origins || ['*'] });
  const server = http.createServer(async (req, res) => {
    securityHeaders(res);
    if (await api(req, res)) return;
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.statusCode = 405;
      return res.end();
    }
    serveStatic(portalDir, req, res);
  });
  return { server, store };
}

module.exports = { createServer, lanAddresses, VERSION };
