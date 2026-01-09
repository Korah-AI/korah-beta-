import { checkRateLimit, getUserId, estimateTokens } from './rate-limit.js';

export default async function handler(req, res) {
  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get user identifier
    const userId = getUserId(req);
    
    // Estimate input tokens from messages
    const messages = req.body.messages || [];
    const inputText = messages.map(m => m.content).join(' ');
    const estimatedInputTokens = estimateTokens(inputText);
    
    // Check rate limit before making API call
    const rateLimitCheck = await checkRateLimit(userId, 0);
    
    // If user is already over limit, reject immediately
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
    
    // Check if estimated tokens would exceed limit
    if (rateLimitCheck.current + estimatedInputTokens > rateLimitCheck.limit) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        message: 'This request would exceed your daily token limit.',
        remaining: rateLimitCheck.remaining,
        resetTime: rateLimitCheck.resetTime,
        current: rateLimitCheck.current,
        limit: rateLimitCheck.limit
      });
    }
    
    // Get the OpenAI API key from environment variables
    const apiKey = process.env.OPENAI_API_KEY;
    
    if (!apiKey) {
      return res.status(500).json({ error: 'API key not configured' });
    }

    // Forward the request to OpenAI API
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(req.body),
    });

    const data = await response.json();
    
    // Update rate limit with actual token usage (if available)
    if (data.usage && data.usage.total_tokens) {
      await checkRateLimit(userId, data.usage.total_tokens);
    } else {
      // Fall back to estimated tokens if usage not provided
      const outputText = data.choices?.[0]?.message?.content || '';
      const estimatedOutputTokens = estimateTokens(outputText);
      await checkRateLimit(userId, estimatedInputTokens + estimatedOutputTokens);
    }
    
    return res.status(response.status).json(data);
  } catch (error) {
    console.error('Proxy error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
