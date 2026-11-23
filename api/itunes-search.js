// Vercel Serverless Function to proxy iTunes Search API queries.
// Runs server-side (Node.js) with no browser CORS or Safari WebKit restrictions.

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept');
  res.setHeader('Cache-Control', 'public, s-maxage=86400, stale-while-revalidate=604800');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const term = req.query.term || req.query.q || req.query.query;
  if (!term || typeof term !== 'string' || !term.trim()) {
    return res.status(400).json({ error: 'Missing term parameter' });
  }

  const country = (req.query.country && typeof req.query.country === 'string')
    ? req.query.country.trim()
    : 'MY';
  const entity = (req.query.entity && typeof req.query.entity === 'string')
    ? req.query.entity.trim()
    : 'song';
  const limit = (req.query.limit && typeof req.query.limit === 'string')
    ? req.query.limit.trim()
    : '25';

  const itunesUrl = new URL('https://itunes.apple.com/search');
  itunesUrl.searchParams.set('term', term.trim());
  itunesUrl.searchParams.set('country', country);
  itunesUrl.searchParams.set('media', 'music');
  itunesUrl.searchParams.set('entity', entity);
  itunesUrl.searchParams.set('limit', limit);

  try {
    const response = await fetch(itunesUrl.toString(), {
      headers: {
        'Accept': 'application/json',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
    });

    if (response.status === 429) {
      return res.status(429).json({ error: 'Rate limited by iTunes API' });
    }

    if (!response.ok) {
      return res.status(response.status).json({
        error: `iTunes returned status ${response.status}`,
      });
    }

    let data = await response.json();

    // If Malaysia storefront returned 0 matches, auto-fallback to US storefront on server
    if (country === 'MY' && (!data.results || data.results.length === 0)) {
      try {
        itunesUrl.searchParams.set('country', 'US');
        const fallbackRes = await fetch(itunesUrl.toString(), {
          headers: {
            'Accept': 'application/json',
            'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        });
        if (fallbackRes.ok) {
          const fallbackData = await fallbackRes.json();
          if (fallbackData.results && fallbackData.results.length > 0) {
            data = fallbackData;
          }
        }
      } catch (_) {}
    }

    return res.status(200).json(data);
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Internal server error' });
  }
}
