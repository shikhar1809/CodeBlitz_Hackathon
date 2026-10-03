/**
 * Winger backend: live session tracking for guardians and a dead-man switch.
 *
 * The app never talks to Firestore directly. It calls `api`:
 *   POST /api/session/start  {name, kind, guardians[]}      -> {id, key, trackUrl}
 *   POST /api/session/beat   {id, key, lat, lon, status, note?}
 *   POST /api/session/end    {id, key, reason}
 *   GET  /api/track/:id      public view for the guardian's tracking page
 *
 * `deadman` runs every minute: an active session whose phone has not checked
 * in for DARK_AFTER_MS is marked "dark" so the guardian's page shows it, and
 * guardians are texted when an SMS provider is configured.
 */
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

const db = admin.firestore();
const SITE = "https://wingercodeblitz.web.app";
const DARK_AFTER_MS = 3 * 60 * 1000;
const MAX_TRAIL = 300;
const STATUSES = new Set(["watching", "checking", "alerting", "silent", "safe", "ended"]);

const sha = (s) => crypto.createHash("sha256").update(String(s)).digest("hex");
const token = (bytes) => crypto.randomBytes(bytes).toString("base64url");

function cors(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

function num(v, lo, hi) {
  const n = Number(v);
  return Number.isFinite(n) && n >= lo && n <= hi ? n : null;
}

function str(v, max) {
  return typeof v === "string" ? v.slice(0, max) : "";
}

/** Loads a session and checks its write key. */
async function authed(body) {
  const id = str(body.id, 64);
  if (!id) return null;
  const ref = db.collection("sessions").doc(id);
  const secret = await db.collection("secrets").doc(id).get();
  if (!secret.exists || secret.get("keyHash") !== sha(body.key)) return null;
  return ref;
}

async function start(req, res) {
  const b = req.body || {};
  const id = token(16);
  const key = token(24);
  const now = Date.now();
  const guardians = Array.isArray(b.guardians)
    ? b.guardians.slice(0, 5).map((g) => str(g, 20)).filter(Boolean)
    : [];
  await db.collection("sessions").doc(id).set({
    name: str(b.name, 40) || "Your friend",
    kind: str(b.kind, 20) || "wingman",
    status: "watching",
    startedAt: now,
    lastBeat: now,
    active: true,
    dark: false,
    location: null,
    trail: [],
    notes: [],
  });
  await db.collection("secrets").doc(id).set({ keyHash: sha(key), guardians });
  res.json({ id, key, trackUrl: `${SITE}/t/${id}` });
}

async function beat(req, res) {
  const b = req.body || {};
  const ref = await authed(b);
  if (!ref) return res.status(403).json({ error: "bad key" });
  const now = Date.now();
  const update = { lastBeat: now, dark: false };
  const lat = num(b.lat, -90, 90);
  const lon = num(b.lon, -180, 180);
  if (lat !== null && lon !== null) {
    update.location = { lat, lon, at: now };
    update.trail = admin.firestore.FieldValue.arrayUnion({ lat, lon, at: now });
  }
  if (STATUSES.has(b.status)) update.status = b.status;
  if (b.note) {
    update.notes = admin.firestore.FieldValue.arrayUnion({ at: now, text: str(b.note, 140) });
  }
  await ref.update(update);
  // Keep the trail bounded.
  const snap = await ref.get();
  const trail = snap.get("trail") || [];
  if (trail.length > MAX_TRAIL) await ref.update({ trail: trail.slice(-MAX_TRAIL) });
  res.json({ ok: true });
}

async function end(req, res) {
  const b = req.body || {};
  const ref = await authed(b);
  if (!ref) return res.status(403).json({ error: "bad key" });
  const safe = b.reason === "safe" || b.reason === "arrived";
  await ref.update({
    active: false,
    status: safe ? "safe" : "ended",
    endedAt: Date.now(),
    notes: admin.firestore.FieldValue.arrayUnion({ at: Date.now(), text: str(b.reason, 60) || "ended" }),
  });
  res.json({ ok: true });
}

async function track(req, res, id) {
  const snap = await db.collection("sessions").doc(str(id, 64)).get();
  if (!snap.exists) return res.status(404).json({ error: "not found" });
  const d = snap.data();
  res.set("Cache-Control", "no-store");
  res.json({
    name: d.name,
    kind: d.kind,
    status: d.status,
    active: d.active,
    dark: d.dark,
    darkAt: d.darkAt || null,
    startedAt: d.startedAt,
    lastBeat: d.lastBeat,
    location: d.location,
    trail: (d.trail || []).slice(-MAX_TRAIL),
    notes: (d.notes || []).slice(-20),
    now: Date.now(),
  });
}

exports.api = onRequest({ cors: false }, async (req, res) => {
  cors(res);
  if (req.method === "OPTIONS") return res.status(204).send("");
  const path = req.path.replace(/^\/api/, "");
  try {
    if (req.method === "POST" && path === "/session/start") return await start(req, res);
    if (req.method === "POST" && path === "/session/beat") return await beat(req, res);
    if (req.method === "POST" && path === "/session/end") return await end(req, res);
    const m = path.match(/^\/track\/([A-Za-z0-9_-]+)$/);
    if (req.method === "GET" && m) return await track(req, res, m[1]);
    res.status(404).json({ error: "no such route" });
  } catch (e) {
    logger.error(e);
    res.status(500).json({ error: "server error" });
  }
});

/** Optional SMS through Twilio when TWILIO_* env vars are set. */
async function sms(to, body) {
  const sid = process.env.TWILIO_SID;
  const auth = process.env.TWILIO_TOKEN;
  const from = process.env.TWILIO_FROM;
  if (!sid || !auth || !from) return false;
  const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: "POST",
    headers: {
      Authorization: "Basic " + Buffer.from(`${sid}:${auth}`).toString("base64"),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ To: to, From: from, Body: body }),
  });
  return r.ok;
}

exports.deadman = onSchedule("every 1 minutes", async () => {
  const cutoff = Date.now() - DARK_AFTER_MS;
  const stale = await db
    .collection("sessions")
    .where("active", "==", true)
    .where("lastBeat", "<", cutoff)
    .limit(50)
    .get();
  for (const doc of stale.docs) {
    if (doc.get("dark")) continue;
    const now = Date.now();
    await doc.ref.update({
      dark: true,
      darkAt: now,
      status: "alerting",
      notes: admin.firestore.FieldValue.arrayUnion({ at: now, text: "Phone went dark" }),
    });
    const secret = await db.collection("secrets").doc(doc.id).get();
    const loc = doc.get("location");
    const where = loc ? ` Last seen: https://maps.google.com/?q=${loc.lat},${loc.lon}` : "";
    for (const g of secret.get("guardians") || []) {
      const sent = await sms(
        g,
        `Winger: ${doc.get("name")}'s phone stopped checking in during a session.${where} Track: ${SITE}/t/${doc.id}`
      ).catch(() => false);
      logger.info("dead-man alert", { session: doc.id, sent });
    }
  }
});
