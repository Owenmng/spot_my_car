/**
 * Spot My Car — serveur gratuit (Google Apps Script, compte noreply.spotmycar@gmail.com).
 *
 * Rôle : codes de vérification par e-mail (inscription, mot de passe oublié, suppression de compte),
 * e-mails de l'appli (bienvenue, support), et API de la console d'administration.
 *
 * Aucune clé secrète dans ce code : le script agit avec le compte Google qui l'exécute,
 * auquel on a donné le rôle « Administrateur Firebase » sur le projet.
 */

const PROJECT = 'car-spotter-app-779f2';
const WEB_API_KEY = 'AIzaSyCt1kTAo-NkFWpTTEt7tlQek_98ruDkwEA';
const BUCKET = 'car-spotter-app-779f2.firebasestorage.app';
const ADMIN_EMAILS = ['owen.mengual@gmail.com'];
const SUPPORT_INBOX = 'owen.mengual@gmail.com';
const APP_NAME = 'Spot My Car';

const CODE_TTL_S = 15 * 60;      // validité d'un code
const CODE_TRIES = 5;            // essais avant invalidation
const SEND_COOLDOWN_S = 45;      // délai entre deux envois
const SENDS_PER_HOUR = 6;        // envois max par adresse et par heure

// ───────────────────────────── Entrées HTTP ─────────────────────────────

function doGet(e) {
  return json_({ ok: true, service: 'spotmycar', time: new Date().toISOString() });
}

function doPost(e) {
  let req = {};
  try {
    req = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  } catch (err) {
    return json_({ ok: false, error: 'bad_request' });
  }
  try {
    const fn = ROUTES[req.action];
    if (!fn) return json_({ ok: false, error: 'unknown_action' });
    const res = fn(req) || {};
    if (res.ok === undefined) res.ok = true;
    return json_(res);
  } catch (err) {
    const code = err && err.code ? err.code : 'server_error';
    if (code === 'server_error') console.error(req.action, err && err.stack ? err.stack : err);
    return json_({ ok: false, error: code, message: err && err.publicMessage ? err.publicMessage : undefined });
  }
}

function json_(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

function fail_(code, publicMessage) {
  const e = new Error(code);
  e.code = code;
  e.publicMessage = publicMessage;
  throw e;
}

const ROUTES = {
  'ping': () => ({ pong: true }),
  'verify.send': verifySend_,
  'verify.check': verifyCheck_,
  'reset.send': resetSend_,
  'reset.check': resetCheck_,
  'reset.apply': resetApply_,
  'delete.send': deleteSend_,
  'delete.apply': deleteApply_,
  'support.send': supportSend_,
  'event': clientEvent_,
  'referral.claim': referralClaim_,
  'plus.verify': plusVerify_,
  'push.notify': pushNotify_,
  // Console d'administration
  'admin.overview': (r) => { requireAdmin_(r); return adminOverview_(r); },
  'admin.users': (r) => { requireAdmin_(r); return adminUsers_(r); },
  'admin.user': (r) => { requireAdmin_(r); return adminUser_(r); },
  'admin.setDisabled': (r) => { requireAdmin_(r); return adminSetDisabled_(r); },
  'admin.deleteUser': (r) => { requireAdmin_(r); return adminDeleteUser_(r); },
  'admin.markVerified': (r) => { requireAdmin_(r); return adminMarkVerified_(r); },
  'admin.plus.set': (r) => { requireAdmin_(r); return adminPlusSet_(r); },
  'admin.mail': (r) => { requireAdmin_(r); return adminMail_(r); },
  'admin.config.get': (r) => { requireAdmin_(r); return { config: getConfig_() }; },
  'admin.config.set': (r) => { requireAdmin_(r); return adminConfigSet_(r); },
  'admin.ideas': (r) => { requireAdmin_(r); return { ideas: listCollection_('admin_ideas', 500) }; },
  'admin.ideas.save': (r) => { requireAdmin_(r); return adminIdeaSave_(r); },
  'admin.ideas.delete': (r) => { requireAdmin_(r); fsDelete_('admin_ideas/' + safeId_(r.id)); return {}; },
  'admin.support': (r) => { requireAdmin_(r); return { tickets: listCollection_('support_tickets', 300) }; },
  'admin.support.update': (r) => { requireAdmin_(r); return adminSupportUpdate_(r); },
  'admin.events': (r) => { requireAdmin_(r); return { events: listCollection_('admin_events', 200, 'at') }; },
  'admin.feedback': (r) => { requireAdmin_(r); return { feedback: listCollection_('recognition_feedback', 200) }; },
  'admin.quota': (r) => { requireAdmin_(r); return { mailQuota: MailApp.getRemainingDailyQuota() }; },
};

// ───────────────────────────── Codes ─────────────────────────────

function secret_() {
  const p = PropertiesService.getScriptProperties();
  let s = p.getProperty('CODE_SECRET');
  if (!s) {
    s = Utilities.getUuid() + Utilities.getUuid();
    p.setProperty('CODE_SECRET', s);
  }
  return s;
}

function hash_(text) {
  const raw = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, text + '|' + secret_(), Utilities.Charset.UTF_8);
  return raw.map((b) => ('0' + (b & 0xff).toString(16)).slice(-2)).join('');
}

function newCode_() {
  const raw = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, Utilities.getUuid() + Date.now() + Math.random());
  let n = 0;
  for (let i = 0; i < 6; i++) n = (n * 256 + (raw[i] & 0xff)) % 1000000000;
  return ('000000' + (n % 1000000)).slice(-6);
}

function codeKey_(purpose, email) {
  return 'code:' + purpose + ':' + String(email).toLowerCase();
}

/** Crée un code, applique les limites d'envoi, renvoie le code en clair (pour l'e-mail). */
function issueCode_(purpose, email, extra) {
  const cache = CacheService.getScriptCache();
  const em = String(email).toLowerCase();
  const rateKey = 'rate:' + purpose + ':' + em;
  const rate = JSON.parse(cache.get(rateKey) || '{"n":0,"last":0}');
  const now = Date.now();
  if (now - rate.last < SEND_COOLDOWN_S * 1000) {
    fail_('cooldown', String(Math.ceil((SEND_COOLDOWN_S * 1000 - (now - rate.last)) / 1000)));
  }
  if (rate.n >= SENDS_PER_HOUR) fail_('too_many');
  if (MailApp.getRemainingDailyQuota() < 3) fail_('mail_quota');
  const code = newCode_();
  cache.put(codeKey_(purpose, em), JSON.stringify(Object.assign({ h: hash_(code + em + purpose), t: 0, at: now }, extra || {})), CODE_TTL_S);
  cache.put(rateKey, JSON.stringify({ n: rate.n + 1, last: now }), 3600);
  return code;
}

/** Vérifie un code. consume=true l'efface s'il est bon. */
function checkCode_(purpose, email, code, consume) {
  const cache = CacheService.getScriptCache();
  const em = String(email).toLowerCase();
  const key = codeKey_(purpose, em);
  const raw = cache.get(key);
  if (!raw) fail_('code_expired');
  const st = JSON.parse(raw);
  const clean = String(code || '').replace(/\D/g, '');
  if (st.h !== hash_(clean + em + purpose)) {
    st.t += 1;
    if (st.t >= CODE_TRIES) {
      cache.remove(key);
      fail_('code_locked');
    }
    const left = Math.max(1, Math.floor((st.at + CODE_TTL_S * 1000 - Date.now()) / 1000));
    cache.put(key, JSON.stringify(st), left);
    fail_('code_wrong', String(CODE_TRIES - st.t));
  }
  if (consume) cache.remove(key);
  return st;
}

// ───────────────────────────── Actions ─────────────────────────────

function verifySend_(r) {
  const u = userFromToken_(r.idToken);
  const lang = lang_(r.lang);
  const code = issueCode_('verify', u.email, { uid: u.uid });
  sendMail_(u.email, 'verify', lang, { code: code, name: firstName_(u) });
  logEvent_('verify.send', { uid: u.uid, email: u.email });
  return { sentTo: maskEmail_(u.email), ttl: CODE_TTL_S, cooldown: SEND_COOLDOWN_S };
}

function verifyCheck_(r) {
  const u = userFromToken_(r.idToken);
  checkCode_('verify', u.email, r.code, true);
  fsPatch_('users/' + u.uid, { emailCodeVerified: true, emailCodeVerifiedAt: new Date() });
  try { authUpdate_({ localId: u.uid, emailVerified: true }); } catch (e) { console.warn(e); }
  try { sendMail_(u.email, 'welcome', lang_(r.lang), { name: firstName_(u) }); } catch (e) { console.warn(e); }
  logEvent_('verify.ok', { uid: u.uid, email: u.email });
  return { verified: true };
}

function resetSend_(r) {
  const email = String(r.email || '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) fail_('bad_email');
  const user = authLookupEmail_(email);
  // Réponse identique que le compte existe ou non (on ne révèle pas qui est inscrit).
  if (!user) return { sentTo: maskEmail_(email), ttl: CODE_TTL_S, cooldown: SEND_COOLDOWN_S };
  if (user.disabled) return { sentTo: maskEmail_(email), ttl: CODE_TTL_S, cooldown: SEND_COOLDOWN_S };
  const code = issueCode_('reset', email, { uid: user.localId });
  sendMail_(email, 'reset', lang_(r.lang), { code: code, name: firstName_({ displayName: user.displayName }) });
  logEvent_('reset.send', { uid: user.localId, email: email });
  return { sentTo: maskEmail_(email), ttl: CODE_TTL_S, cooldown: SEND_COOLDOWN_S };
}

function resetCheck_(r) {
  const email = String(r.email || '').trim().toLowerCase();
  checkCode_('reset', email, r.code, false);
  return { valid: true };
}

function resetApply_(r) {
  const email = String(r.email || '').trim().toLowerCase();
  const pwd = String(r.password || '');
  if (pwd.length < 6) fail_('weak_password');
  if (pwd.length > 128) fail_('weak_password');
  const st = checkCode_('reset', email, r.code, true);
  authUpdate_({ localId: st.uid, password: pwd, emailVerified: true });
  try { sendMail_(email, 'resetDone', lang_(r.lang), {}); } catch (e) { console.warn(e); }
  logEvent_('reset.ok', { uid: st.uid, email: email });
  return { changed: true };
}

function deleteSend_(r) {
  const u = userFromToken_(r.idToken);
  const code = issueCode_('delete', u.email, { uid: u.uid });
  sendMail_(u.email, 'delete', lang_(r.lang), { code: code, name: firstName_(u) });
  logEvent_('delete.send', { uid: u.uid, email: u.email });
  return { sentTo: maskEmail_(u.email), ttl: CODE_TTL_S, cooldown: SEND_COOLDOWN_S };
}

function deleteApply_(r) {
  const u = userFromToken_(r.idToken);
  checkCode_('delete', u.email, r.code, true);
  const profile = fsGet_('users/' + u.uid) || {};
  deleteUserEverywhere_(u.uid);
  try { sendMail_(u.email, 'deleted', lang_(r.lang), { name: profile.pseudo || firstName_(u) }); } catch (e) { console.warn(e); }
  logEvent_('delete.ok', { uid: u.uid, email: u.email, pseudo: profile.pseudo || null });
  return { deleted: true };
}

function supportSend_(r) {
  let u = null;
  try { if (r.idToken) u = userFromToken_(r.idToken); } catch (e) { u = null; }
  const subject = String(r.subject || '').slice(0, 160);
  const message = String(r.message || '').slice(0, 5000);
  const topic = String(r.topic || 'Autre').slice(0, 40);
  if (!subject || !message) fail_('bad_request');
  const from = u ? u.email : String(r.email || '').slice(0, 120);
  const rateKey = 'support:' + (u ? u.uid : from);
  const cache = CacheService.getScriptCache();
  const n = Number(cache.get(rateKey) || 0);
  if (n >= 5) fail_('too_many');
  cache.put(rateKey, String(n + 1), 3600);
  const ctx = r.context && typeof r.context === 'object' ? r.context : {};
  const id = fsCreate_('support_tickets', {
    at: new Date(), uid: u ? u.uid : null, email: from || null, topic: topic, subject: subject,
    message: message, context: JSON.stringify(ctx).slice(0, 2000), status: 'nouveau',
  });
  const rows = Object.keys(ctx).map((k) => [k, String(ctx[k])]);
  MailApp.sendEmail({
    to: SUPPORT_INBOX,
    subject: '[Support · ' + topic + '] ' + subject,
    htmlBody: supportInboxHtml_(topic, subject, message, from, rows, id),
    name: APP_NAME + ' · Support',
    replyTo: from || undefined,
  });
  if (from) {
    try { sendMail_(from, 'supportAck', lang_(r.lang), { subject: subject, ticket: id.slice(0, 6).toUpperCase() }); } catch (e) { console.warn(e); }
  }
  logEvent_('support', { uid: u ? u.uid : null, email: from, subject: subject });
  return { ticket: id };
}

/** Petits événements envoyés par l'appli (ex. note Play Store). */
function clientEvent_(r) {
  const allowed = ['rate.prompt', 'rate.accept', 'rate.later', 'tutorial.done', 'tutorial.skip', 'plate.lookup', 'app.error'];
  if (allowed.indexOf(r.name) < 0) fail_('bad_request');
  let uid = null;
  try { uid = userFromToken_(r.idToken).uid; } catch (e) { uid = null; }
  if (r.name === 'app.error') {
    // Erreurs d'affichage remontées par l'appli : 20 max par heure et par joueur, sans doublons.
    const detail = String(r.detail || '').slice(0, 400);
    const cache = CacheService.getScriptCache();
    const who = uid || 'anon';
    const n = Number(cache.get('err_n_' + who) || 0);
    const sig = 'err_' + Utilities.base64EncodeWebSafe(Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, who + detail));
    if (n >= 20 || cache.get(sig)) return {};
    cache.put('err_n_' + who, String(n + 1), 3600);
    cache.put(sig, '1', 21600);
    logEvent_('app.error', { uid: uid, detail: detail });
    return {};
  }
  logEvent_(r.name, { uid: uid, detail: String(r.detail || '').slice(0, 120) });
  return {};
}

// ───────────────────────────── Suppression complète ─────────────────────────────

function deleteUserEverywhere_(uid) {
  // Firestore : profil + sous-collections, spots, photos, demandes d'amis.
  ['private', 'friends'].forEach((sub) => {
    listDocs_('users/' + uid + '/' + sub, 500).forEach((d) => fsDelete_(d.path));
  });
  fsDelete_('users/' + uid);
  const spots = runQuery_('spotted_cars', [['userId', 'EQUAL', uid]], 2000);
  spots.forEach((d) => {
    fsDelete_(d.path);
    fsDelete_('spot_photos/' + d.id);
  });
  runQuery_('friend_requests', [['fromUserId', 'EQUAL', uid]], 500).forEach((d) => fsDelete_(d.path));
  runQuery_('friend_requests', [['toUserId', 'EQUAL', uid]], 500).forEach((d) => fsDelete_(d.path));
  // Storage : photo de profil et photos de spots.
  ['profile_pictures/' + uid, 'user_spots/' + uid + '/'].forEach((prefix) => {
    try {
      storageList_(prefix).forEach((name) => storageDelete_(name));
    } catch (e) { console.warn('storage', e); }
  });
  // Compte de connexion.
  try { authDelete_(uid); } catch (e) { if (String(e).indexOf('USER_NOT_FOUND') < 0) throw e; }
}

// ───────────────────────────── Identité ─────────────────────────────

function userFromToken_(idToken) {
  if (!idToken) fail_('auth_required');
  const res = UrlFetchApp.fetch('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + WEB_API_KEY, {
    method: 'post', contentType: 'application/json', payload: JSON.stringify({ idToken: idToken }), muteHttpExceptions: true,
  });
  if (res.getResponseCode() !== 200) fail_('auth_invalid');
  const u = (JSON.parse(res.getContentText()).users || [])[0];
  if (!u || !u.email) fail_('auth_invalid');
  if (u.disabled) fail_('auth_disabled');
  return { uid: u.localId, email: String(u.email).toLowerCase(), emailVerified: !!u.emailVerified, displayName: u.displayName || '', providers: (u.providerUserInfo || []).map((p) => p.providerId) };
}

function requireAdmin_(r) {
  const u = userFromToken_(r.idToken);
  if (ADMIN_EMAILS.indexOf(u.email) < 0 || !u.emailVerified) fail_('forbidden');
  return u;
}

function firstName_(u) {
  const n = String((u && u.displayName) || '').trim();
  return n ? n.split(/\s+/)[0] : '';
}

function maskEmail_(email) {
  const [a, d] = String(email).split('@');
  if (!d) return email;
  const shown = a.length <= 2 ? a[0] : a.slice(0, 2);
  return shown + '•••' + (a.length > 4 ? a.slice(-1) : '') + '@' + d;
}

function lang_(l) {
  l = String(l || 'fr').slice(0, 2).toLowerCase();
  return ['fr', 'en', 'es', 'de', 'it', 'pt'].indexOf(l) >= 0 ? l : 'en';
}

function safeId_(id) {
  id = String(id || '');
  if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) fail_('bad_request');
  return id;
}

// ───────────────────────────── API Google ─────────────────────────────

function gapi_(method, url, body, opt) {
  const params = {
    method: method,
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken(), 'x-goog-user-project': PROJECT },
    muteHttpExceptions: true,
  };
  if (body !== undefined && body !== null) {
    params.contentType = 'application/json';
    params.payload = JSON.stringify(body);
  }
  const res = UrlFetchApp.fetch(url, params);
  const code = res.getResponseCode();
  const text = res.getContentText();
  if (code === 404 && opt && opt.allow404) return null;
  if (code >= 300) throw new Error('Google API ' + code + ' ' + url.split('?')[0] + ' : ' + text.slice(0, 400));
  return text ? JSON.parse(text) : {};
}

const IDT = 'https://identitytoolkit.googleapis.com/v1/projects/' + PROJECT;

function authLookupEmail_(email) {
  const r = gapi_('post', IDT + '/accounts:lookup', { email: [email] });
  return (r.users || [])[0] || null;
}
function authLookupUid_(uid) {
  const r = gapi_('post', IDT + '/accounts:lookup', { localId: [uid] });
  return (r.users || [])[0] || null;
}
function authUpdate_(body) { return gapi_('post', IDT + '/accounts:update', body); }
function authDelete_(uid) { return gapi_('post', IDT + '/accounts:delete', { localId: uid }); }
function authAll_() {
  const out = [];
  let token = '';
  for (let i = 0; i < 20; i++) {
    const r = gapi_('get', IDT + '/accounts:batchGet?maxResults=1000' + (token ? '&nextPageToken=' + encodeURIComponent(token) : ''));
    (r.users || []).forEach((u) => out.push(u));
    if (!r.nextPageToken) break;
    token = r.nextPageToken;
  }
  return out;
}

// Firestore REST
const FS = 'https://firestore.googleapis.com/v1/projects/' + PROJECT + '/databases/(default)/documents';

function toFs_(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFs_) } };
  if (typeof v === 'object') {
    const fields = {};
    Object.keys(v).forEach((k) => (fields[k] = toFs_(v[k])));
    return { mapValue: { fields: fields } };
  }
  return { stringValue: String(v) };
}

function fromFs_(v) {
  if (!v) return null;
  if ('nullValue' in v) return null;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('stringValue' in v) return v.stringValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('geoPointValue' in v) return v.geoPointValue;
  if ('referenceValue' in v) return v.referenceValue;
  if ('bytesValue' in v) return '[bytes]';
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(fromFs_);
  if ('mapValue' in v) {
    const o = {};
    const f = v.mapValue.fields || {};
    Object.keys(f).forEach((k) => (o[k] = fromFs_(f[k])));
    return o;
  }
  return null;
}

function docOut_(d) {
  const o = fromFs_({ mapValue: { fields: d.fields || {} } });
  const rel = d.name.split('/documents/')[1];
  o._id = rel.split('/').pop();
  o._path = rel;
  return { id: o._id, path: rel, data: o };
}

function fsGet_(path) {
  const d = gapi_('get', FS + '/' + path, null, { allow404: true });
  return d ? docOut_(d).data : null;
}

function fsPatch_(path, obj) {
  const mask = Object.keys(obj).map((k) => 'updateMask.fieldPaths=' + encodeURIComponent(k)).join('&');
  const fields = {};
  Object.keys(obj).forEach((k) => (fields[k] = toFs_(obj[k])));
  return gapi_('patch', FS + '/' + path + '?' + mask, { fields: fields });
}

function fsSet_(path, obj) {
  const fields = {};
  Object.keys(obj).forEach((k) => (fields[k] = toFs_(obj[k])));
  return gapi_('patch', FS + '/' + path, { fields: fields });
}

function fsCreate_(collection, obj) {
  const fields = {};
  Object.keys(obj).forEach((k) => (fields[k] = toFs_(obj[k])));
  const d = gapi_('post', FS + '/' + collection, { fields: fields });
  return d.name.split('/').pop();
}

function fsDelete_(path) {
  return gapi_('delete', FS + '/' + path, null, { allow404: true });
}

function listDocs_(collectionPath, max) {
  const out = [];
  let token = '';
  while (out.length < max) {
    const r = gapi_('get', FS + '/' + collectionPath + '?pageSize=300' + (token ? '&pageToken=' + encodeURIComponent(token) : ''), null, { allow404: true });
    if (!r) break;
    (r.documents || []).forEach((d) => out.push(docOut_(d)));
    if (!r.nextPageToken) break;
    token = r.nextPageToken;
  }
  return out.slice(0, max);
}

function listCollection_(collection, max, orderField) {
  const docs = orderField
    ? runQuery_(collection, [], max, { field: orderField, dir: 'DESCENDING' })
    : listDocs_(collection, max);
  return docs.map((d) => d.data);
}

function runQuery_(collection, filters, limit, order) {
  const q = { from: [{ collectionId: collection }], limit: limit || 500 };
  if (filters && filters.length) {
    const fs = filters.map((f) => ({ fieldFilter: { field: { fieldPath: f[0] }, op: f[1], value: toFs_(f[2]) } }));
    q.where = fs.length === 1 ? fs[0] : { compositeFilter: { op: 'AND', filters: fs } };
  }
  if (order) q.orderBy = [{ field: { fieldPath: order.field }, direction: order.dir || 'DESCENDING' }];
  const r = gapi_('post', FS + ':runQuery', { structuredQuery: q });
  return (r || []).filter((x) => x.document).map((x) => docOut_(x.document));
}

function countQuery_(collection, filters) {
  const q = { from: [{ collectionId: collection }] };
  if (filters && filters.length) {
    const fs = filters.map((f) => ({ fieldFilter: { field: { fieldPath: f[0] }, op: f[1], value: toFs_(f[2]) } }));
    q.where = fs.length === 1 ? fs[0] : { compositeFilter: { op: 'AND', filters: fs } };
  }
  const r = gapi_('post', FS + ':runAggregationQuery', {
    structuredAggregationQuery: { structuredQuery: q, aggregations: [{ alias: 'n', count: {} }] },
  });
  const res = (r || [])[0];
  return res && res.result ? Number(res.result.aggregateFields.n.integerValue) : 0;
}

// Storage
function storageList_(prefix) {
  const r = gapi_('get', 'https://storage.googleapis.com/storage/v1/b/' + BUCKET + '/o?prefix=' + encodeURIComponent(prefix), null, { allow404: true });
  return r && r.items ? r.items.map((i) => i.name) : [];
}
function storageDelete_(name) {
  return gapi_('delete', 'https://storage.googleapis.com/storage/v1/b/' + BUCKET + '/o/' + encodeURIComponent(name), null, { allow404: true });
}

// ───────────────────────────── Configuration à distance ─────────────────────────────

const DEFAULT_CONFIG = {
  maintenance: false,
  maintenanceMessage: '',
  announcement: '',
  announcementLevel: 'info',
  announcementId: '',
  features: {
    blindTest: true,
    duels: true,
    community: true,
    map: true,
    plateLookup: true,
    aiRecognition: true,
    ratePrompt: true,
    tutorial: true,
    emailVerification: true,
    dailyChest: true,
    wanted: true,
    referral: true,
    shareStats: true,
    premium: true,
    rewardedAds: true,
  },
  minVersion: 0,
  latestVersion: 0,
  updateMessage: '',
};

function getConfig_() {
  const c = fsGet_('config/app') || {};
  const out = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
  Object.keys(c).forEach((k) => {
    if (k.charAt(0) === '_') return;
    if (k === 'features' && c.features) Object.assign(out.features, c.features);
    else out[k] = c[k];
  });
  return out;
}

function adminConfigSet_(r) {
  const c = r.config || {};
  const clean = getConfig_();
  ['maintenance'].forEach((k) => { if (k in c) clean[k] = !!c[k]; });
  ['maintenanceMessage', 'announcement', 'announcementLevel', 'updateMessage'].forEach((k) => { if (k in c) clean[k] = String(c[k] || '').slice(0, 600); });
  ['minVersion', 'latestVersion'].forEach((k) => { if (k in c) clean[k] = Math.max(0, Math.floor(Number(c[k]) || 0)); });
  if (c.features) Object.keys(clean.features).forEach((k) => { if (k in c.features) clean.features[k] = !!c.features[k]; });
  if ('announcement' in c) clean.announcementId = clean.announcement ? String(Date.now()) : '';
  clean.updatedAt = new Date();
  fsSet_('config/app', clean);
  logEvent_('admin.config', { detail: JSON.stringify(c).slice(0, 200) });
  return { config: getConfig_() };
}

// ───────────────────────────── Journal ─────────────────────────────

function logEvent_(type, data) {
  try {
    fsCreate_('admin_events', Object.assign({ type: type, at: new Date() }, data || {}));
  } catch (e) {
    console.warn('log', e);
  }
}


// ───────────────────────────── Parrainage ─────────────────────────────
// Le filleul saisit le code ami (friendId) de son parrain dans les 30 jours
// qui suivent son inscription : +REFERRAL_XP pour chacun, une seule fois.

const REFERRAL_XP = 300;
const REFERRAL_WINDOW_DAYS = 30;
const REFERRAL_MAX = 200; // plafond par parrain (anti-abus)

function referralClaim_(r) {
  const u = userFromToken_(r.idToken);
  const code = String(r.code || '').replace(/\s+/g, '').toLowerCase();
  if (!/^[0-9a-z]{4,24}$/.test(code)) fail_('ref_not_found');
  const me = fsGet_('users/' + u.uid) || {};
  if (me.referredBy) fail_('ref_already');
  const acc = authLookupUid_(u.uid);
  if (acc && Date.now() - Number(acc.createdAt || 0) > REFERRAL_WINDOW_DAYS * 86400000) fail_('ref_too_old');
  let found = runQuery_('users', [['friendId_lowercase', 'EQUAL', code]], 1);
  if (!found.length) found = runQuery_('users', [['friendId', 'EQUAL', code]], 1);
  if (!found.length) fail_('ref_not_found');
  const sponsor = found[0];
  if (sponsor.id === u.uid) fail_('ref_self');
  if (Number(sponsor.data.referralCount || 0) >= REFERRAL_MAX) fail_('ref_full');
  const week = isoWeek_(new Date());
  fsCommitInc_('users/' + u.uid, { referredBy: sponsor.id, referredAt: new Date() }, { totalXp: REFERRAL_XP, ['xpByWeek.`' + week + '`']: REFERRAL_XP });
  fsCommitInc_('users/' + sponsor.id, { lastReferralAt: new Date() }, { totalXp: REFERRAL_XP, referralCount: 1, ['xpByWeek.`' + week + '`']: REFERRAL_XP });
  logEvent_('referral', { uid: u.uid, sponsor: sponsor.id });
  return { xp: REFERRAL_XP, sponsor: sponsor.data.pseudo || '' };
}

/** Semaine ISO « 2026W46 », identique à weekKey() côté appli. */
function isoWeek_(d) {
  const day = d.getDay() || 7;
  const thursday = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 4 - day);
  const first = new Date(thursday.getFullYear(), 0, 1);
  const week = 1 + Math.floor(Math.round((thursday - first) / 86400000) / 7);
  return thursday.getFullYear() + 'W' + (week < 10 ? '0' : '') + week;
}

/** Mise à jour atomique : champs posés + incréments (FieldValue.increment). */
function fsCommitInc_(path, set, inc) {
  const name = 'projects/' + PROJECT + '/databases/(default)/documents/' + path;
  const fields = {};
  Object.keys(set).forEach((k) => (fields[k] = toFs_(set[k])));
  return gapi_('post', FS + ':commit', {
    writes: [{
      update: { name: name, fields: fields },
      updateMask: { fieldPaths: Object.keys(set) },
      updateTransforms: Object.keys(inc).map((k) => ({ fieldPath: k, increment: toFs_(inc[k]) })),
      currentDocument: { exists: true },
    }],
  });
}

// ───────────────────────────── Spot My Car+ ─────────────────────────────
// Vérifie un abonnement Google Play et écrit plus.until dans le profil.
// Prérequis (une fois) : API « Google Play Android Developer » activée sur le projet,
// le compte du serveur invité dans la Play Console (droits « commandes et abonnements »),
// et le scope androidpublisher dans appsscript.json.

const PACKAGE_NAME = 'com.owenmengual.spotmycar';
const PLUS_IDS = ['spotmycar_plus_mensuel', 'spotmycar_plus_annuel'];
const PLUS_OK = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_CANCELED'];

function plusVerify_(r) {
  const u = userFromToken_(r.idToken);
  const productId = String(r.productId || '');
  const token = String(r.purchaseToken || '');
  if (PLUS_IDS.indexOf(productId) < 0 || !token || token.length > 2000) fail_('bad_request');
  let s;
  try {
    s = gapi_('get', 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + PACKAGE_NAME +
      '/purchases/subscriptionsv2/tokens/' + encodeURIComponent(token));
  } catch (e) {
    // Accès à l'API Play pas encore autorisé pour le serveur : on active à titre provisoire
    // (7 jours, marqué « UNVERIFIED » dans la console) pour ne jamais bloquer un vrai client.
    if (!/ 40[13] /.test(String(e)) || token.length < 80) throw e;
    const h0 = hex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, token, Utilities.Charset.UTF_8));
    const prev0 = fsGet_('plus_tokens/' + h0);
    if (prev0 && prev0.uid && prev0.uid !== u.uid) fail_('plus_owned');
    const until0 = Date.now() + 7 * 86400000;
    fsSet_('plus_tokens/' + h0, { uid: u.uid, productId: productId, state: 'UNVERIFIED', until: new Date(until0), updatedAt: new Date() });
    fsPatch_('users/' + u.uid, { plus: { until: new Date(until0), productId: productId, state: 'UNVERIFIED', verifiedAt: new Date() } });
    logEvent_('plus.unverified', { uid: u.uid, productId: productId, error: String(e).slice(0, 160) });
    return { active: true, until: new Date(until0).toISOString(), provisional: true };
  }
  let until = 0;
  (s.lineItems || []).forEach((li) => { const t = Date.parse(li.expiryTime); if (t > until) until = t; });
  const active = PLUS_OK.indexOf(s.subscriptionState) >= 0 && until > Date.now();
  // Un achat = un compte : on refuse qu'un même jeton active plusieurs profils.
  const h = hex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, token, Utilities.Charset.UTF_8));
  const prev = fsGet_('plus_tokens/' + h);
  if (prev && prev.uid && prev.uid !== u.uid) fail_('plus_owned');
  fsSet_('plus_tokens/' + h, { uid: u.uid, productId: productId, state: s.subscriptionState || '', until: new Date(until || Date.now()), updatedAt: new Date() });
  if (active) {
    fsPatch_('users/' + u.uid, { plus: { until: new Date(until), productId: productId, state: s.subscriptionState, verifiedAt: new Date() } });
  }
  logEvent_('plus.verify', { uid: u.uid, productId: productId, state: s.subscriptionState, active: active });
  return { active: active, until: until ? new Date(until).toISOString() : null };
}

// ───────────────────────────── Notifications push ─────────────────────────────
// L'appli signale un événement social ; le serveur vérifie qu'il existe vraiment
// (et que c'est bien l'auteur qui le signale) puis prévient l'autre joueur via FCM.

const PUSH_TEXT = {
  friend_request: { fr: ['Nouvelle demande d’ami', '{0} veut t’ajouter en ami. Accepte pour comparer vos garages !'], en: ['New friend request', '{0} wants to add you as a friend.'], es: ['Nueva solicitud de amistad', '{0} quiere añadirte como amigo.'], de: ['Neue Freundschaftsanfrage', '{0} möchte dich als Freund hinzufügen.'], it: ['Nuova richiesta di amicizia', '{0} vuole aggiungerti come amico.'], pt: ['Novo pedido de amizade', '{0} quer adicionar-te como amigo.'] },
  friend_accept: { fr: ['Demande acceptée 🤝', '{0} est maintenant ton ami. Défie-le en duel !'], en: ['Request accepted 🤝', '{0} is now your friend. Challenge them to a duel!'], es: ['Solicitud aceptada 🤝', '{0} ya es tu amigo. ¡Rétalo a un duelo!'], de: ['Anfrage angenommen 🤝', '{0} ist jetzt dein Freund. Fordere ihn zum Duell!'], it: ['Richiesta accettata 🤝', '{0} ora è tuo amico. Sfidalo a duello!'], pt: ['Pedido aceite 🤝', '{0} é agora teu amigo. Desafia-o para um duelo!'] },
  duel: { fr: ['⚔️ Défi en duel', '{0} te lance un duel. Tu relèves le défi ?'], en: ['⚔️ Duel challenge', '{0} challenged you to a duel. Game on?'], es: ['⚔️ Reto a duelo', '{0} te reta a un duelo. ¿Aceptas?'], de: ['⚔️ Duell-Herausforderung', '{0} fordert dich zum Duell heraus. Nimmst du an?'], it: ['⚔️ Sfida a duello', '{0} ti sfida a duello. Accetti?'], pt: ['⚔️ Desafio de duelo', '{0} desafiou-te para um duelo. Aceitas?'] },
  duel_accept: { fr: ['⚔️ Duel accepté', '{0} a accepté ton duel. Que le meilleur spotteur gagne !'], en: ['⚔️ Duel accepted', '{0} accepted your duel. May the best spotter win!'], es: ['⚔️ Duelo aceptado', '{0} aceptó tu duelo. ¡Que gane el mejor!'], de: ['⚔️ Duell angenommen', '{0} hat dein Duell angenommen. Möge der Beste gewinnen!'], it: ['⚔️ Duello accettato', '{0} ha accettato il tuo duello. Vinca il migliore!'], pt: ['⚔️ Duelo aceite', '{0} aceitou o teu duelo. Que ganhe o melhor!'] },
};

function pushNotify_(r) {
  const u = userFromToken_(r.idToken);
  const kind = String(r.kind || '');
  const ref = safeId_(r.ref);
  if (!PUSH_TEXT[kind]) fail_('bad_request');
  const cache = CacheService.getScriptCache();
  const key = 'push:' + kind + ':' + ref;
  if (cache.get(key)) return { sent: 0, dup: true };
  let target = null;
  if (kind === 'friend_request' || kind === 'friend_accept') {
    const d = fsGet_('friend_requests/' + ref);
    if (!d) fail_('not_found');
    if (kind === 'friend_request' && d.fromUserId === u.uid) target = d.toUserId;
    if (kind === 'friend_accept' && d.toUserId === u.uid && d.status === 'accepted') target = d.fromUserId;
  } else {
    const d = fsGet_('duels/' + ref);
    if (!d) fail_('not_found');
    if (kind === 'duel' && d.challengerId === u.uid) target = d.opponentId;
    if (kind === 'duel_accept' && d.opponentId === u.uid && d.status === 'active') target = d.challengerId;
  }
  if (!target) fail_('forbidden');
  cache.put(key, '1', 21600);
  const me = fsGet_('users/' + u.uid) || {};
  const to = fsGet_('users/' + safeId_(target)) || {};
  const tokens = (to.fcmTokens || []).filter(Boolean).slice(-5);
  if (!tokens.length) return { sent: 0 };
  const lang = lang_(to.language || to.appLanguage || 'fr');
  const t = PUSH_TEXT[kind][lang] || PUSH_TEXT[kind].fr;
  const name = me.pseudo || me.firstName || 'Un spotteur';
  let sent = 0;
  const dead = [];
  tokens.forEach((token) => {
    try {
      gapi_('post', 'https://fcm.googleapis.com/v1/projects/' + PROJECT + '/messages:send', {
        message: {
          token: token,
          notification: { title: t[0], body: t[1].replace('{0}', name) },
          data: { kind: kind, ref: ref },
          android: { priority: 'HIGH', notification: { channel_id: 'spotmycar_social', color: '#E5202E', sound: 'default' } },
        },
      });
      sent++;
    } catch (e) {
      if (/UNREGISTERED|NOT_FOUND|INVALID_ARGUMENT/.test(String(e))) dead.push(token);
    }
  });
  if (dead.length) fsPatch_('users/' + safeId_(target), { fcmTokens: tokens.filter((x) => dead.indexOf(x) < 0) });
  logEvent_('push', { uid: u.uid, to: target, kind: kind, sent: sent });
  return { sent: sent };
}
