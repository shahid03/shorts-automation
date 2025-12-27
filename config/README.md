# Configuration Directory

Place your credential files here:

- `google-credentials.json` - Google Drive/Sheets service account credentials
- `youtube-credentials.json` - YouTube API OAuth credentials

## Getting Credentials

### Google Service Account
1. Go to Google Cloud Console
2. Create a new project or select existing
3. Enable Google Drive API and Google Sheets API
4. Create Service Account
5. Download JSON key file
6. Rename to `google-credentials.json`

### YouTube OAuth
1. Go to Google Cloud Console
2. Enable YouTube Data API v3
3. Create OAuth 2.0 Client ID
4. Download credentials
5. Rename to `youtube-credentials.json`

**Important:** Never commit these files to version control!
