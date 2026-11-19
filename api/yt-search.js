// Vercel Serverless Function to search YouTube and return a videoId for a song query.
// Runs server-side (Node.js) with no browser CORS restrictions.

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const query = req.query.q || req.query.query;
  if (!query || typeof query !== 'string') {
    return res.status(400).json({ error: 'Missing query parameter q' });
  }

  try {
    const url = `https://www.youtube.com/results?search_query=${encodeURIComponent(query.trim())}`;
    const response = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    });

    if (!response.ok) {
      return res.status(response.status).json({ error: `YouTube returned status ${response.status}` });
    }

    const html = await response.text();
    // Match the first videoId pattern
    const match = html.match(/"videoId":"([a-zA-Z0-9_-]{11})"/);
    if (match && match[1]) {
      return res.status(200).json({ videoId: match[1] });
    }

    return res.status(404).json({ error: 'No videoId found in search results' });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Internal server error' });
  }
}
