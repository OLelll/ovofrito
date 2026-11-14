/* /sitemap.xml: lista todas as matérias publicadas pro Google achar. */
const SB_URL = 'https://axazzmqbnpexnnezcthp.supabase.co';
const SB_KEY = 'sb_publishable_glOkzjOROWcXY6IUsQD8lQ_EgbEEj_v';
const x = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
module.exports = async (req, res) => {
  const origin = 'https://' + (req.headers['x-forwarded-host'] || req.headers.host || '');
  let list = [];
  try {
    const r = await fetch(`${SB_URL}/rest/v1/content?key=eq.articles&select=value`, { headers: { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY } });
    const j = await r.json(); list = Array.isArray(j[0] && j[0].value) ? j[0].value : [];
  } catch (e) {}
  list = list.filter(a => !a.pubAt || Date.parse(a.pubAt) <= Date.now());
  const urls = [`<url><loc>${origin}/</loc></url>`].concat(list.map(a => `<url><loc>${x(origin + '/materia/' + (a.slug || a.id))}</loc></url>`));
  res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  res.setHeader('Cache-Control', 'public, s-maxage=600, stale-while-revalidate=3600');
  res.status(200).send(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>`);
};
