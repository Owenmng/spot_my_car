/** API de la console d'administration (réservée aux adresses de ADMIN_EMAILS). */

/** Cache serveur court (60 s) : la console reste instantanée même avec beaucoup de clics. */
function cached_(key, ttl, fn) {
  const cache = CacheService.getScriptCache();
  try {
    const hit = cache.get(key);
    if (hit) return JSON.parse(hit);
  } catch (e) {}
  const v = fn();
  try {
    const txt = JSON.stringify(v);
    if (txt.length < 95000) cache.put(key, txt, ttl);
  } catch (e) {}
  return v;
}
function bust_() {
  CacheService.getScriptCache().removeAll(['adm:users', 'adm:overview']);
}

function tsMs_(v) {
  if (!v) return 0;
  if (typeof v === 'number') return v;
  const n = Number(v);
  if (!isNaN(n) && String(v).length >= 12) return n; // millisecondes (Auth)
  const d = Date.parse(v);
  return isNaN(d) ? 0 : d;
}

function adminUsers_(r) {
  if (r && r.fresh) bust_();
  return cached_('adm:users', 60, () => adminUsersRaw_());
}

function adminUsersRaw_() {
  const auth = authAll_();
  const profiles = {};
  listDocs_('users', 5000).forEach((d) => (profiles[d.id] = d.data));
  const users = auth.map((a) => {
    const p = profiles[a.localId] || {};
    const stats = p.stats || {};
    return {
      uid: a.localId,
      email: a.email || p.email || '',
      emailVerified: !!a.emailVerified,
      disabled: !!a.disabled,
      providers: (a.providerUserInfo || []).map((x) => x.providerId),
      createdAt: Number(a.createdAt || 0),
      lastLoginAt: Number(a.lastLoginAt || 0),
      lastSeenAt: tsMs_(p.lastSeenAt) || Number(a.lastRefreshAt ? Date.parse(a.lastRefreshAt) : 0) || Number(a.lastLoginAt || 0),
      displayName: a.displayName || '',
      photoUrl: p.photoUrl || a.photoUrl || '',
      pseudo: p.pseudo || '',
      firstName: p.firstName || '',
      lastName: p.lastName || '',
      profileCompleted: !!p.profileCompleted,
      totalXp: Number(p.totalXp || 0),
      totalSpots: Number(stats.totalSpots || 0),
      uniqueBrands: Number(stats.uniqueBrands || 0),
      uniqueModels: Number(stats.uniqueModels || 0),
      favoriteBrand: stats.favoriteBrandName || '',
      friendId: p.friendId || '',
      appVersion: p.appVersion || '',
      language: p.language || p.appLanguage || '',
      platform: p.platform || '',
      emailCodeRequired: !!p.emailCodeRequired,
      emailCodeVerified: !!p.emailCodeVerified,
      streak: Number(p.streak || (p.dailyStreak && p.dailyStreak.count) || 0),
      hasProfile: !!profiles[a.localId],
    };
  });
  users.sort((a, b) => b.createdAt - a.createdAt);
  return { users: users };
}

function adminUser_(r) {
  const uid = safeId_(r.uid);
  const a = authLookupUid_(uid);
  const p = fsGet_('users/' + uid);
  const spots = runQuery_('spotted_cars', [['userId', 'EQUAL', uid]], 300).map((d) => {
    const s = d.data;
    return {
      id: d.id, brand: s.brandName || '', model: s.modelName || '', plate: s.plate || '', rarity: s.rarity || '',
      xp: s.xp || 0, at: s.spottedAt || null, place: s.locationName || '', country: s.plateCountryCode || '',
      image: s.modelImageUrl || '', color: s.color || '', aiGuess: s.aiGuess || '', catalogued: !!s.isCatalogued,
    };
  });
  spots.sort((x, y) => tsMs_(y.at) - tsMs_(x.at));
  const events = runQuery_('admin_events', [['uid', 'EQUAL', uid]], 60).map((d) => d.data);
  events.sort((x, y) => tsMs_(y.at) - tsMs_(x.at));
  return { auth: a, profile: p, spots: spots, events: events };
}

function adminSetDisabled_(r) {
  bust_();
  const uid = safeId_(r.uid);
  authUpdate_({ localId: uid, disableUser: !!r.disabled });
  logEvent_(r.disabled ? 'admin.disable' : 'admin.enable', { uid: uid });
  return { disabled: !!r.disabled };
}

function adminDeleteUser_(r) {
  bust_();
  const uid = safeId_(r.uid);
  const a = authLookupUid_(uid);
  deleteUserEverywhere_(uid);
  logEvent_('admin.delete', { uid: uid, email: a ? a.email : null });
  return { deleted: true };
}

function adminMarkVerified_(r) {
  bust_();
  const uid = safeId_(r.uid);
  fsPatch_('users/' + uid, { emailCodeVerified: true, emailCodeVerifiedAt: new Date() });
  try { authUpdate_({ localId: uid, emailVerified: true }); } catch (e) { console.warn(e); }
  logEvent_('admin.verify', { uid: uid });
  return { verified: true };
}

function adminMail_(r) {
  let email = String(r.email || '');
  if (r.uid) {
    const a = authLookupUid_(safeId_(r.uid));
    if (!a) fail_('not_found');
    email = a.email;
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) fail_('bad_email');
  const subject = String(r.subject || '').slice(0, 160);
  const message = String(r.message || '').slice(0, 8000);
  if (!subject || !message) fail_('bad_request');
  sendMail_(email, 'custom', lang_(r.lang || 'fr'), { subject: subject, message: message });
  logEvent_('admin.mail', { uid: r.uid || null, email: email, subject: subject });
  return { sent: true };
}

function adminIdeaSave_(r) {
  const i = r.idea || {};
  const data = {
    title: String(i.title || '').slice(0, 160),
    notes: String(i.notes || '').slice(0, 4000),
    status: ['idee', 'a_faire', 'en_cours', 'fait'].indexOf(i.status) >= 0 ? i.status : 'idee',
    priority: ['basse', 'normale', 'haute'].indexOf(i.priority) >= 0 ? i.priority : 'normale',
    tag: String(i.tag || '').slice(0, 30),
    updatedAt: new Date(),
  };
  if (!data.title) fail_('bad_request');
  if (i.id) {
    fsPatch_('admin_ideas/' + safeId_(i.id), data);
    return { id: i.id };
  }
  data.createdAt = new Date();
  return { id: fsCreate_('admin_ideas', data) };
}

function adminSupportUpdate_(r) {
  const id = safeId_(r.id);
  const status = ['nouveau', 'en_cours', 'resolu'].indexOf(r.status) >= 0 ? r.status : 'nouveau';
  fsPatch_('support_tickets/' + id, { status: status, updatedAt: new Date() });
  return { status: status };
}

function adminOverview_(r) {
  if (r && r.fresh) bust_();
  return cached_('adm:overview', 60, () => adminOverviewRaw_());
}

function adminOverviewRaw_() {
  const now = Date.now();
  const day = 86400000;
  const auth = authAll_();
  const profiles = {};
  listDocs_('users', 5000).forEach((d) => (profiles[d.id] = d.data));
  const totalUsers = auth.length;
  const seen = auth.map((a) => {
    const p = profiles[a.localId] || {};
    return Math.max(tsMs_(p.lastSeenAt), Number(a.lastLoginAt || 0), a.lastRefreshAt ? Date.parse(a.lastRefreshAt) : 0);
  });
  const active = (d) => seen.filter((t) => now - t < d * day).length;
  // Inscriptions par jour (30 derniers jours)
  const signups = [];
  for (let i = 29; i >= 0; i--) {
    const start = new Date(now - i * day); start.setHours(0, 0, 0, 0);
    const end = start.getTime() + day;
    signups.push({ day: Utilities.formatDate(start, 'Europe/Paris', 'dd/MM'), n: auth.filter((a) => Number(a.createdAt) >= start.getTime() && Number(a.createdAt) < end).length });
  }
  const providers = {};
  auth.forEach((a) => (a.providerUserInfo || []).forEach((p) => (providers[p.providerId] = (providers[p.providerId] || 0) + 1)));
  const langs = {}, versions = {};
  Object.keys(profiles).forEach((k) => {
    const p = profiles[k];
    const lg = p.language || p.appLanguage; if (lg) langs[lg] = (langs[lg] || 0) + 1;
    if (p.appVersion) versions[p.appVersion] = (versions[p.appVersion] || 0) + 1;
  });
  // Spots
  const totalSpots = countQuery_('spotted_cars', []);
  const recent = runQuery_('spotted_cars', [], 400, { field: 'spottedAt', dir: 'DESCENDING' }).map((d) => d.data);
  const spotsByDay = [];
  for (let i = 29; i >= 0; i--) {
    const start = new Date(now - i * day); start.setHours(0, 0, 0, 0);
    const end = start.getTime() + day;
    spotsByDay.push({ day: Utilities.formatDate(start, 'Europe/Paris', 'dd/MM'), n: recent.filter((s) => tsMs_(s.spottedAt) >= start.getTime() && tsMs_(s.spottedAt) < end).length });
  }
  const brands = {}, rarities = {}, countries = {};
  recent.forEach((s) => {
    if (s.brandName) brands[s.brandName] = (brands[s.brandName] || 0) + 1;
    if (s.rarity) rarities[s.rarity] = (rarities[s.rarity] || 0) + 1;
    if (s.plateCountryCode) countries[s.plateCountryCode] = (countries[s.plateCountryCode] || 0) + 1;
  });
  const top = (o, n) => Object.keys(o).map((k) => ({ k: k, n: o[k] })).sort((a, b) => b.n - a.n).slice(0, n);
  const lastSpots = recent.slice(0, 12).map((s) => ({
    brand: s.brandName, model: s.modelName, at: s.spottedAt, rarity: s.rarity, uid: s.userId,
    pseudo: (profiles[s.userId] || {}).pseudo || '', image: s.modelImageUrl || '', place: s.locationName || '',
  }));
  const tickets = runQuery_('support_tickets', [['status', 'EQUAL', 'nouveau']], 50).length;
  return {
    totals: {
      users: totalUsers,
      profiles: Object.keys(profiles).length,
      spots: totalSpots,
      dau: active(1), wau: active(7), mau: active(30),
      newUsers7: auth.filter((a) => now - Number(a.createdAt) < 7 * day).length,
      spots7: recent.filter((s) => now - tsMs_(s.spottedAt) < 7 * day).length,
      openTickets: tickets,
      mailQuota: MailApp.getRemainingDailyQuota(),
      disabled: auth.filter((a) => a.disabled).length,
    },
    signups: signups,
    spotsByDay: spotsByDay,
    providers: providers,
    languages: langs,
    versions: versions,
    topBrands: top(brands, 10),
    rarities: rarities,
    countries: top(countries, 8),
    lastSpots: lastSpots,
    sampleSize: recent.length,
  };
}
