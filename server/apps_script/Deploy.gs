/**
 * Outils lancés à la main depuis l'éditeur Apps Script :
 *  - selfTest()      : vérifie les accès (Auth, Firestore, Storage, e-mail)
 *  - deployRules()   : publie firestore_rules.html comme règles Firestore
 *  - deployHosting() : publie la console d'admin et la page d'accueil sur Firebase Hosting
 */

function selfTest() {
  const out = {};
  out.mailQuota = MailApp.getRemainingDailyQuota();
  try { out.authUsers = gapi_('get', IDT + '/accounts:batchGet?maxResults=5').users.length; } catch (e) { out.auth = String(e); }
  try { out.firestoreUsers = listDocs_('users', 3).length; } catch (e) { out.firestore = String(e); }
  try { out.config = getConfig_(); } catch (e) { out.configErr = String(e); }
  try { out.storage = storageList_('profile_pictures/').length; } catch (e) { out.storageErr = String(e); }
  console.log(JSON.stringify(out, null, 2));
  return out;
}

function previewMails() {
  const to = Session.getEffectiveUser().getEmail();
  sendMail_(to, 'verify', 'fr', { code: '482913', name: 'Max' });
  sendMail_(to, 'welcome', 'fr', { name: 'Max' });
}

function deployRules() {
  const content = b64text_(FIRESTORE_RULES_B64);
  const rs = gapi_('post', 'https://firebaserules.googleapis.com/v1/projects/' + PROJECT + '/rulesets', {
    source: { files: [{ name: 'firestore.rules', content: content }] },
  });
  const rel = 'projects/' + PROJECT + '/releases/cloud.firestore';
  const r = gapi_('patch', 'https://firebaserules.googleapis.com/v1/' + rel, { release: { name: rel, rulesetName: rs.name } });
  console.log('Règles publiées : ' + rs.name + ' -> ' + JSON.stringify(r));
  return rs.name;
}

function b64text_(b64) {
  return Utilities.newBlob(Utilities.base64Decode(b64)).getDataAsString('UTF-8');
}

function hex_(bytes) {
  return bytes.map((b) => ('0' + (b & 0xff).toString(16)).slice(-2)).join('');
}

function deployHosting() {
  const site = PROJECT;
  const H = 'https://firebasehosting.googleapis.com/v1beta1';
  const files = {};
  Object.keys(SITE_FILES).forEach((k) => (files[k] = b64text_(SITE_FILES[k]).replace('__SERVER_URL__', serverUrl_())));
  const blobs = {};
  const hashes = {};
  Object.keys(files).forEach((path) => {
    const gz = Utilities.gzip(Utilities.newBlob(files[path], 'text/html', 'f.html'));
    const bytes = gz.getBytes();
    const h = hex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, bytes));
    hashes[path] = h;
    blobs[h] = bytes;
  });
  const version = gapi_('post', H + '/sites/' + site + '/versions', {
    config: {
      headers: [{ glob: '**', headers: { 'Cache-Control': 'no-cache', 'X-Robots-Tag': 'noindex' } }],
      cleanUrls: true,
      trailingSlashBehavior: 'ADD',
    },
  });
  const pop = gapi_('post', H + '/' + version.name + ':populateFiles', { files: hashes });
  (pop.uploadRequiredHashes || []).forEach((h) => {
    const res = UrlFetchApp.fetch(pop.uploadUrl + '/' + h, {
      method: 'post', contentType: 'application/octet-stream', payload: blobs[h],
      headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken(), 'x-goog-user-project': PROJECT }, muteHttpExceptions: true,
    });
    if (res.getResponseCode() >= 300) throw new Error('upload ' + res.getResponseCode() + ' ' + res.getContentText());
  });
  gapi_('patch', H + '/' + version.name + '?update_mask=status', { status: 'FINALIZED' });
  const rel = gapi_('post', H + '/sites/' + site + '/releases?versionName=' + encodeURIComponent(version.name), {});
  console.log('Hébergement publié : https://' + site + '.web.app  (' + rel.name + ')');
  return rel.name;
}

/** URL publique du serveur (déploiement « Application Web »). */
function serverUrl_() {
  const fixed = PropertiesService.getScriptProperties().getProperty('SERVER_URL');
  return fixed || ScriptApp.getService().getUrl();
}
