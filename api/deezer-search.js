// Vercel Serverless Function to proxy Deezer Search API queries.
// Runs server-side (Node.js) with no browser CORS or Safari WebKit restrictions.

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept');
  res.setHeader('Cache-Control', 'public, s-maxage=86400, stale-while-revalidate=604800');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const query = req.query.q || req.query.term || req.query.query;
  if (!query || typeof query !== 'string' || !query.trim()) {
    return res.status(400).json({ error: 'Missing query parameter' });
  }

  const limit = (req.query.limit && typeof req.query.limit === 'string')
    ? req.query.limit.trim()
    : '25';

  const deezerUrl = new URL('https://api.deezer.com/search');
  deezerUrl.searchParams.set('q', query.trim());
  deezerUrl.searchParams.set('limit', limit);

  try {
    const response = await fetch(deezerUrl.toString(), {
      headers: {
        'Accept': 'application/json',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
    });

    if (response.status === 429) {
      return res.status(429).json({ error: 'Rate limited by Deezer API' });
    }

    if (!response.ok) {
      return res.status(response.status).json({
        error: `Deezer returned status ${response.status}`,
      });
    }

    const data = await response.json();
    return res.status(200).json(data);
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Internal server error' });
  }
}
