const json = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  },
  body: JSON.stringify(body),
});

const prompt = desc =>
`You are a clinical nutritionist. Analyze the food from the image, description, or both.${desc ? ` User context: "${desc}"` : ''}
Return ONLY a raw JSON object — no markdown, no explanation:
{"mealName":"specific dish name","calories":450,"protein":32.5,"carbs":28.0,"fat":18.5,"fiber":4.2,"ingredients":["item with estimated quantity"],"confidence":"high|medium|low","portionNote":"brief estimation note"}
Calories in kcal. Macros in grams. Do not underestimate portions.`;

exports.handler = async event => {
  if (event.httpMethod === 'OPTIONS') return json(204, {});
  if (event.httpMethod !== 'POST') return json(405, { error: 'Method not allowed' });

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return json(500, { error: 'OPENAI_API_KEY is not configured on Netlify.' });

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch {
    return json(400, { error: 'Invalid JSON body.' });
  }

  const img = payload.img || null;
  const desc = String(payload.desc || '').trim();
  if (!img && !desc) return json(400, { error: 'Please provide an image, a description, or both.' });
  if (img?.b64 && img.b64.length > 7_000_000) return json(413, { error: 'Image is too large.' });

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
    return json(res.status, { error: data.error?.message || `OpenAI request failed with HTTP ${res.status}` });
  }

  return json(200, { text: data.choices?.[0]?.message?.content || '' });
};
