const configuredOrigins = () => new Set([
  process.env.URL,
  process.env.DEPLOY_PRIME_URL,
  ...(process.env.ALLOWED_ORIGINS || '').split(','),
].map(origin => origin?.trim()).filter(Boolean));

const requestOrigin = event => event.headers.origin || event.headers.Origin || '';
const isLocalOrigin = origin => {
  try {
    const { hostname } = new URL(origin);
    return hostname === 'localhost' || hostname === '127.0.0.1';
  } catch {
    return false;
  }
};

const corsHeaders = event => {
  const origin = requestOrigin(event);
  const allowedOrigins = configuredOrigins();
  const allowedOrigin = allowedOrigins.has(origin) || isLocalOrigin(origin) ? origin : process.env.URL || '';

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'Content-Type, X-Meal-Tracker-Token',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
};

const json = (event, statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    ...corsHeaders(event),
  },
  body: JSON.stringify(body),
});

const prompt = desc =>
`You are a clinical nutritionist. Analyze the food from the image, description, or both.${desc ? ` User context: "${desc}"` : ''}
Return ONLY a raw JSON object — no markdown, no explanation:
{"mealName":"specific dish name","calories":450,"protein":32.5,"carbs":28.0,"fat":18.5,"fiber":4.2,"ingredients":["item with estimated quantity"],"confidence":"high|medium|low","portionNote":"brief estimation note"}
Calories in kcal. Macros in grams. Do not underestimate portions.`;

exports.handler = async event => {
  if (event.httpMethod === 'OPTIONS') return json(event, 204, {});
  if (event.httpMethod !== 'POST') return json(event, 405, { error: 'Method not allowed' });

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return json(event, 500, { error: 'OPENAI_API_KEY is not configured on Netlify.' });

  const origin = requestOrigin(event);
  const allowedOrigins = configuredOrigins();
  if (origin && !allowedOrigins.has(origin) && !isLocalOrigin(origin)) {
    return json(event, 403, { error: 'Origin is not allowed.' });
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch {
    return json(event, 400, { error: 'Invalid JSON body.' });
  }

  const img = payload.img || null;
  const desc = String(payload.desc || '').trim();
  if (!img && !desc) return json(event, 400, { error: 'Please provide an image, a description, or both.' });
  if (desc.length > 2000) return json(event, 413, { error: 'Description is too long.' });
  if (img?.b64 && img.b64.length > 7_000_000) return json(event, 413, { error: 'Image is too large.' });
  if (img?.type && !['image/jpeg', 'image/png', 'image/webp'].includes(img.type)) {
    return json(event, 415, { error: 'Unsupported image type.' });
  }

  const content = [
    ...(img?.b64 && img?.type
      ? [{ type: 'image_url', image_url: { url: `data:${img.type};base64,${img.b64}` } }]
      : []),
    { type: 'text', text: prompt(desc) },
  ];

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      max_tokens: 1000,
      messages: [{ role: 'user', content }],
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return json(event, res.status, { error: data.error?.message || `OpenAI request failed with HTTP ${res.status}` });
  }

  return json(event, 200, { text: data.choices?.[0]?.message?.content || '' });
};
