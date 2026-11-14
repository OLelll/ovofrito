/* Vercel: entrega o index.html com título, descrição e imagem de cada matéria nas tags
   (é o que WhatsApp, Instagram, Google etc. leem). Depois o site abre normalmente. */
const fs = require('fs'), path = require('path');
const SB_URL = 'https://axazzmqbnpexnnezcthp.supabase.co';
const SB_KEY = 'sb_publishable_glOkzjOROWcXY6IUsQD8lQ_EgbEEj_v'; /* chave pública, a mesma do site */
const esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const isLive = a => !a.pubAt || Date.parse(a.pubAt) <= Date.now();
const cut = (t, n) => { t = String(t || '').replace(/\s+/g, ' ').trim(); return t.length <= n ? t : t.slice(0, n - 1).replace(/\s+\S*$/, '') + '…'; };

async function loadArticles() {
  const r = await fetch(`${SB_URL}/rest/v1/rpc/public_articles`, { method: 'POST', headers: { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' }, body: '{}' });
  if (!r.ok) throw new Error('supabase ' + r.status);
  const j = await r.json();
  return Array.isArray(j) ? j : [];
}

function render(html, a, origin) {
  const slug = a.slug || a.id;
  const title = (a.seoT || a.t || 'Ovo Frito') + ' · Ovo Frito';
  const desc = cut(a.seoD || a.x || '', 200) || 'Cinema e séries sem enrolação.';
  const url = `${origin}/materia/${slug}`;
  const img = /^https:\/\//.test(a.img || '') ? a.img : origin + '/og.png';
  const tags = [
    ['property="og:type"', 'article'], ['property="og:title"', title], ['property="og:description"', desc],
    ['property="og:url"', url], ['property="og:image"', img], ['property="og:site_name"', 'Ovo Frito'],
    ['name="twitter:card"', 'summary_large_image'], ['name="twitter:title"', title], ['name="twitter:description"', desc], ['name="twitter:image"', img]
  ].map(([k, v]) => `<meta ${k} content="${esc(v)}">`).join('\n') + `\n<link rel="canonical" href="${esc(url)}">`;
  html = html.replace(/<meta (property="og:|name="twitter:)[^>]*>/g, '');
  html = html.replace(/<title>[\s\S]*?<\/title>/, `<title>${esc(title)}</title>`);
  html = html.replace(/<meta name="description"[^>]*>/, `<meta name="description" content="${esc(desc)}">\n${tags}`);
  /* o site está em outra pasta no GitHub Pages; aqui os arquivos ficam na raiz */
  html = html.replace(/(href|src)="(favicon\.svg|favicon\.png|apple-touch-icon\.png)"/g, '$1="/$2"');
  return html;
}

module.exports = async (req, res) => {
  const host = req.headers['x-forwarded-host'] || req.headers.host || '';
  const origin = 'https://' + host;
  let html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  html = html.replace(/(href|src)="(favicon\.svg|favicon\.png|apple-touch-icon\.png)"/g, '$1="/$2"');
  const slug = String((req.query && req.query.slug) || '').replace(/[^\w-]/g, '');
  try {
    const a = slug && (await loadArticles()).find(x => (x.slug === slug || x.id === slug) && isLive(x));
    if (a) html = render(html, a, origin);
  } catch (e) { /* sem banco: entrega o site normal */ }
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=600');
  res.status(200).send(html);
};
module.exports.render = render;
