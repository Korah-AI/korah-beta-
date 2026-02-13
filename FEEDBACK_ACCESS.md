# Accessing Beta Feedback Data

Your feedback system logs all beta tester feedback to Vercel server logs. Here's how to access it:

## Viewing Feedback in Vercel Dashboard

### 1. Access Vercel Logs
1. Go to https://vercel.com/dashboard
2. Select your project: `korah-beta`
3. Click on the **Logs** tab in the navigation
4. Filter logs by the function: `api/feedback`

### 2. Feedback Log Format
Each feedback submission will appear in logs like this:
```
=== KORAH BETA FEEDBACK ===
{
  "id": "feedback:1234567890:abc123",
  "category": "Bug Report",
  "message": "User's feedback message here...",
  "deviceId": "unique-device-id",
  "appVersion": "1.0.0",
  "timestamp": "2026-01-17T23:00:00.000Z",
  "userAgent": "iOS/18.0 ..."
}
=========================
```

### 3. Search and Filter
In the Vercel Logs interface, you can:
- Search for `KORAH BETA FEEDBACK` to see all feedback
- Filter by date range
- Search for specific categories (e.g., "Bug Report")
- Search by device ID to track feedback from same user
- Export logs if needed

## Alternative: Log Aggregation Service (Optional)

For better feedback management, you can forward logs to a service like:
- **Logtail** (free tier available)
- **Datadog** 
- **Papertrail**

These services provide better search, filtering, and analysis capabilities.

## Creating a Feedback Viewer (Optional)

If you want to collect feedback in a database later, you can add a simple service like:

### Option 1: Google Sheets
Modify the API to also send data to Google Sheets via their API

### Option 2: Airtable
Use Airtable's REST API to store feedback in a table

### Option 3: Simple JSON File in Vercel Blob Storage
Store feedback in Vercel's blob storage for easy retrieval

## Feedback Data Structure

Each feedback entry contains:
```json
{
  "id": "feedback:1234567890:abc123",
  "category": "Bug Report | Feature Request | General Feedback | Help/Support",
  "message": "User's feedback message",
  "deviceId": "unique-device-id",
  "appVersion": "1.0.0",
  "timestamp": "2026-01-17T23:00:00.000Z",
  "userAgent": "iOS/18.0 ..."
}
```

## Notes
- All feedback is logged to Vercel with timestamp for easy chronological access
- Device IDs help you track multiple submissions from the same user
- Vercel logs are retained based on your plan (typically 1-7 days on free tier)
- For longer retention, consider forwarding to a log aggregation service
