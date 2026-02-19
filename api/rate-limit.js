import { Redis } from '@upstash/redis';

// Initialize Upstash Redis client
const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN,
});

// Daily token limits
const DAILY_TOKEN_LIMIT = 200000; // 200K tokens per day per user

/**
 * Check and update token usage for rate limiting
 * @param {string} userId - Unique identifier for the user (device ID or IP)
 * @param {number} tokensUsed - Number of tokens consumed in this request
 * @returns {Promise<{allowed: boolean, remaining: number, resetTime: string, current: number, limit: number}>}
 */
export async function checkRateLimit(userId, tokensUsed = 0) {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const key = `rate_limit:${userId}:${today}`;
  
  try {
    // Add timeout wrapper for Redis operations (3 second timeout)
    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Redis timeout')), 3000)
    );
    
    // Get current usage with timeout
    const currentUsage = await Promise.race([
      redis.get(key),
      timeoutPromise
    ]).then(val => val || 0);
    
    const newUsage = Number(currentUsage) + tokensUsed;
    
    // Check if limit exceeded
    if (newUsage > DAILY_TOKEN_LIMIT) {
      const tomorrow = new Date();
      tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
      tomorrow.setUTCHours(0, 0, 0, 0);
      
      return {
        allowed: false,
        remaining: 0,
        resetTime: tomorrow.toISOString(),
        current: Number(currentUsage),
        limit: DAILY_TOKEN_LIMIT
      };
    }
    
    // Update usage with 24-hour expiry (86400 seconds) - with timeout
    await Promise.race([
      redis.set(key, newUsage, { ex: 86400 }),
      timeoutPromise
    ]);
    
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    tomorrow.setUTCHours(0, 0, 0, 0);
    
    return {
      allowed: true,
      remaining: DAILY_TOKEN_LIMIT - newUsage,
      resetTime: tomorrow.toISOString(),
      current: newUsage,
      limit: DAILY_TOKEN_LIMIT
    };
  } catch (error) {
    console.error('Rate limit check failed:', error);
    // Fail open - allow request if rate limiting system fails
    return {
      allowed: true,
      remaining: DAILY_TOKEN_LIMIT,
      resetTime: new Date().toISOString(),
      current: 0,
      limit: DAILY_TOKEN_LIMIT
    };
  }
}

/**
 * Get user identifier from request
 * @param {Request} req - Vercel request object
 * @returns {string} User identifier
 */
export function getUserId(req) {
  // Option 1: Use custom device ID header from app (recommended)
  const deviceId = req.headers['x-device-id'];
  if (deviceId) return deviceId;
  
  // Option 2: Fall back to IP address
  const forwarded = req.headers['x-forwarded-for'];
  const ip = forwarded ? forwarded.split(',')[0].trim() : req.socket?.remoteAddress;
  
  return ip || 'unknown';
}

/**
 * Estimate tokens from text (rough approximation: 1 token ≈ 4 characters)
 * @param {string} text - Text to estimate
 * @returns {number} Estimated token count
 */
export function estimateTokens(text) {
  if (!text) return 0;
  return Math.ceil(text.length / 4);
}
