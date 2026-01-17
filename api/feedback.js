/**
 * Feedback submission endpoint
 * Logs user feedback to Vercel server logs
 */
export default async function handler(req, res) {
  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { category, message, deviceId, appVersion } = req.body;

    // Validate required fields
    if (!category || !message) {
      return res.status(400).json({ 
        error: 'Missing required fields',
        message: 'Category and message are required'
      });
    }

    // Create feedback entry
    const feedbackId = `feedback:${Date.now()}:${Math.random().toString(36).substring(7)}`;
    const feedback = {
      id: feedbackId,
      category,
      message,
      deviceId: deviceId || 'unknown',
      appVersion: appVersion || 'unknown',
      timestamp: new Date().toISOString(),
      userAgent: req.headers['user-agent'] || 'unknown'
    };

    // Log feedback to Vercel logs (viewable in Vercel dashboard)
    console.log('=== KORAH BETA FEEDBACK ===');
    console.log(JSON.stringify(feedback, null, 2));
    console.log('=========================');

    return res.status(200).json({
      success: true,
      message: 'Thank you for your feedback!',
      feedbackId
    });

  } catch (error) {
    console.error('Feedback submission error:', error);
    return res.status(500).json({ 
      error: 'Internal server error',
      message: 'Failed to submit feedback. Please try again.'
    });
  }
}
