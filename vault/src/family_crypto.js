'use strict';
/**
 * The family code and what is derived from it. Identical in the phone app
 * (Dart), the family portal (WebCrypto) and here (Node), so all three agree
 * byte for byte.
 *
 *   family code   16 random bytes, shown as 26 Crockford base32 characters
 *   household id  HKDF-SHA256(code, salt "winger", info "household-id"), 8 bytes, hex
 *   access token  HKDF-SHA256(code, salt "winger", info "access"), 32 bytes, base64url
 *   data key      HKDF-SHA256(code, salt "winger", info "data"), 32 bytes, AES-256-GCM
 *
 * The server only ever sees the household id, a hash of the access token
 * and ciphertext. It cannot read a single medicine name.
 */
const crypto = require('crypto');

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford: no I, L, O, U

function encodeCode(bytes) {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const b of bytes) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

function decodeCode(code) {
  const clean = String(code)
    .toUpperCase()
    .replace(/[\s-]/g, '')
    .replace(/O/g, '0')
    .replace(/[IL]/g, '1');
  if (!/^[0-9A-HJKMNP-TV-Z]{26}$/.test(clean)) throw new Error('bad family code');
  let bits = 0;
  let value = 0;
  const out = [];
  for (const ch of clean) {
    value = (value << 5) | ALPHABET.indexOf(ch);
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out.slice(0, 16));
}

/** "ABCD-EFGH-…" for people to read out. */
function formatCode(code) {
  return code.replace(/(.{4})(?=.)/g, '$1-');
}

function newFamilyCode() {
  return encodeCode(crypto.randomBytes(16));
}

function hkdf(secret, info, length) {
  return Buffer.from(crypto.hkdfSync('sha256', secret, Buffer.from('winger'), Buffer.from(info), length));
}

function derive(code) {
  const secret = decodeCode(code);
  return {
    householdId: hkdf(secret, 'household-id', 8).toString('hex'),
    accessToken: hkdf(secret, 'access', 32).toString('base64url'),
    dataKey: hkdf(secret, 'data', 32),
  };
}

const sha256 = (s) => crypto.createHash('sha256').update(String(s)).digest('hex');

/** AES-256-GCM. The household id and record kind are bound in as AAD. */
function seal(key, plaintext, aad = '') {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  c.setAAD(Buffer.from(aad));
  const body = Buffer.concat([c.update(Buffer.from(plaintext)), c.final(), c.getAuthTag()]);
  return { iv: iv.toString('base64'), ct: body.toString('base64') };
}

function open(key, box, aad = '') {
  const body = Buffer.from(box.ct, 'base64');
  const d = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(box.iv, 'base64'));
  d.setAAD(Buffer.from(aad));
  d.setAuthTag(body.subarray(body.length - 16));
  return Buffer.concat([d.update(body.subarray(0, body.length - 16)), d.final()]).toString('utf8');
}

module.exports = { encodeCode, decodeCode, formatCode, newFamilyCode, derive, sha256, seal, open };
