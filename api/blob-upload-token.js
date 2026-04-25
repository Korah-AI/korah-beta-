import { generateClientTokenFromReadWriteToken } from '@vercel/blob/client';

const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
const ALLOWED_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];

function sanitizeFilename(filename) {
  const fallback = 'scan-image.jpg';
  if (!filename || typeof filename !== 'string') {
    return fallback;
  }

  const cleaned = filename
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');

  return cleaned || fallback;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Device-ID');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    if (!process.env.BLOB_READ_WRITE_TOKEN) {
      return res.status(500).json({ error: 'Blob storage not configured' });
    }

    const {
      filename,
      contentType,
      byteSize,
      messageId,
    } = req.body ?? {};

    if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
      return res.status(400).json({ error: 'Unsupported content type' });
    }

    if (typeof byteSize !== 'number' || byteSize <= 0 || byteSize > MAX_IMAGE_BYTES) {
      return res.status(400).json({ error: 'Image size is invalid or exceeds upload limit' });
    }

    const deviceId = req.headers['x-device-id'] || 'unknown-device';
    const safeFilename = sanitizeFilename(filename);
    const safeMessageId = typeof messageId === 'string' && messageId ? messageId : Date.now().toString();
    const pathname = `scanner/${deviceId}/${safeMessageId}/${safeFilename}`;

    const clientToken = await generateClientTokenFromReadWriteToken({
      token: process.env.BLOB_READ_WRITE_TOKEN,
      pathname,
      access: 'public',
      addRandomSuffix: true,
      maximumSizeInBytes: MAX_IMAGE_BYTES,
      allowedContentTypes: ALLOWED_CONTENT_TYPES,
      validUntil: Date.now() + (5 * 60 * 1000),
    });

    return res.status(200).json({
      clientToken,
      pathname,
      uploadURL: 'https://vercel.com/api/blob',
    });
  } catch (error) {
    console.error('Blob token generation error:', error);
    return res.status(500).json({ error: 'Failed to create upload token' });
  }
}
