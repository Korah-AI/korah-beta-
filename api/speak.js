import { checkRateLimit, getUserId, estimateTokens } from './rate-limit.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get user identifier
    const userId = getUserId(req);
    
    // Estimate tokens for TTS (roughly 1 token per character)
    const inputText = req.body.input || '';
    const estimatedTokens = Math.ceil(inputText.length);
    
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

    // Forward the request to OpenAI TTS API
    const response = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(req.body),
    });

    // Return audio data as binary
    const audioBuffer = await response.arrayBuffer();
    
    // Update token usage
    await checkRateLimit(userId, estimatedTokens);
    
    res.setHeader('Content-Type', 'audio/mpeg');
    return res.status(response.status).send(Buffer.from(audioBuffer));
  } catch (error) {
    console.error('TTS proxy error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
