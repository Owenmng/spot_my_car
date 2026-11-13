// Captures de contrôle de l'aperçu web : node tool/shots_v11.js <url_base> <dossier>
const { chromium } = require('playwright');
(async () => {
  const [base, out] = process.argv.slice(2);
  const demos = ['tuto0', 'tuto1', 'tuto2', 'tuto3', 'tuto4', 'tuto5', 'verify', 'forgot', 'delete', 'plate', 'plate_fni', 'music', 'maintenance', 'rate'];
  const b = await chromium.launch();
  for (const lang of ['fr', 'en']) {
    for (const d of demos) {
      if (lang === 'en' && !['tuto1', 'verify', 'plate'].includes(d)) continue;
      const p = await b.newPage({ viewport: { width: 412, height: 892 }, deviceScaleFactor: 2, locale: lang });
      await p.addInitScript((l) => { try { localStorage.setItem('flutter.app_language', JSON.stringify(l)); } catch (e) {} }, lang);
      await p.goto(`${base}/?demo=${d}`, { waitUntil: 'networkidle' }).catch(() => {});
      await p.waitForTimeout(d.startsWith('tuto') ? 4200 : 3000);
      await p.screenshot({ path: `${out}/${lang}_${d}.png` });
      await p.close();
    }
  }
  await b.close();
})();
