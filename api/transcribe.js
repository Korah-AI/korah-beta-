import { checkRateLimit, getUserId } from './rate-limit.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get user identifier
    const userId = getUserId(req);
    
    // Estimate fixed cost per transcription (Whisper is cheap, ~100 tokens per minute)
    const estimatedTokens = 500; // Conservative estimate for typical audio
    
    // Check rate limit
    const rateLimitCheck = await checkRateLimit(userId, 0);
    
    if (!rateLimitCheck.allowed) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        message: 'Daily token limit reached. Please try again tomorrow.',
        remaining: rateLimitCheck.remaining,
        resetTime: rateLimitCheck.resetTime,
        current: rateLimitCheck.current,
        limit: rateLimitCheck.limit
      });
    }
    
    // Check if this request would exceed limit
    if (rateLimitCheck.current + estimatedTokens > rateLimitCheck.limit) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        message: 'This request would exceed your daily token limit.',
        remaining: rateLimitCheck.remaining,
        resetTime: rateLimitCheck.resetTime,
        current: rateLimitCheck.current,
        limit: rateLimitCheck.limit
      });
    }
    
    const apiKey = process.env.OPENAI_API_KEY;
    
    if (!apiKey) {
      return res.status(500).json({ error: 'API key not configured' });
    }

    // Read the raw body
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const body = Buffer.concat(chunks);

    // Forward multipart form data to OpenAI Whisper API
    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': req.headers['content-type'],
      },
      body: body,
    });

    const data = await response.json();
    
    // Update token usage after successful transcription
    await checkRateLimit(userId, estimatedTokens);
    
    return res.status(response.status).json(data);
  } catch (error) {
    console.error('Transcription proxy error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

export const config = {
  api: {
    bodyParser: false,
  },
};
