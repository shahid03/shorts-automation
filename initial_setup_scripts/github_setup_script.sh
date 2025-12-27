#!/bin/bash

# Stoic Shorts Automation - Complete Setup Script
# Run this in your cloned repository directory

echo "🏛️  Setting up Stoic Shorts Automation..."

# Create directory structure
mkdir -p config src/services src/utils data/stoic_shorts/{images,voiceovers,videos} logs

# ============================================
# FILE 1: package.json
# ============================================
cat > package.json << 'EOF'
{
  "name": "stoic-shorts-automation",
  "version": "1.0.0",
  "description": "Automated Stoic short video generation and publishing system",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [
    "automation",
    "video",
    "stoic",
    "ai"
  ],
  "author": "",
  "license": "MIT",
  "dependencies": {
    "axios": "^1.6.0",
    "aws-sdk": "^2.1500.0",
    "dotenv": "^16.3.1",
    "form-data": "^4.0.0",
    "googleapis": "^128.0.0",
    "node-cron": "^3.0.3",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# ============================================
# FILE 2: .gitignore
# ============================================
cat > .gitignore << 'EOF'
# Environment
.env
.env.local

# Credentials
config/*-credentials.json
config/google-credentials.json
config/youtube-credentials.json

# Dependencies
node_modules/
package-lock.json
yarn.lock

# Logs
logs/
*.log

# Generated content
data/
*.mp4
*.mp3
*.png
*.jpg

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Build
dist/
build/
EOF

# ============================================
# FILE 3: .env.example
# ============================================
cat > .env.example << 'EOF'
# .env.example - Copy to .env and fill in your values

# === AI Model Configuration ===
LLM_PROVIDER=openrouter
LLM_MODEL=deepseek/deepseek-chat-v3-0324
LLM_API_KEY=your_api_key_here
LLM_BASE_URL=https://openrouter.ai/api/v1

# === Image Generation ===
IMAGE_GEN_TYPE=comfyui
COMFYUI_URL=http://localhost:8188
COMFYUI_CHECKPOINT=realisticStockPhoto_v20.safetensors
IMAGE_WIDTH=544
IMAGE_HEIGHT=960
IMAGE_STEPS=30
IMAGE_CFG=8

# === Voice Generation ===
VOICE_URL=http://localhost:8880/v1/audio/speech
VOICE_MODEL=kokoro
VOICE_NAME=am_michael

# === Video Settings ===
NUM_IMAGES=2
VIDEO_OUTPUT_DIR=./data/stoic_shorts
TRANSITION_STYLE=fade

# === Captions ===
CAPTIONS_ENABLED=true
CAPTION_SERVICE_URL=http://localhost:8080/v1/video/caption
CAPTION_API_KEY=thekey
CAPTION_LINE_COLOR=#FFFFFF
CAPTION_WORD_COLOR=FFFF00
CAPTION_OUTLINE_COLOR=#000000
CAPTION_ALL_CAPS=true
CAPTION_MAX_WORDS=10
CAPTION_POSITION=bottom_center
CAPTION_FONT_SIZE=96
CAPTION_FONT_FAMILY=Arial
CAPTION_BOLD=true

# === Google Drive ===
GOOGLE_DRIVE_ENABLED=false
GOOGLE_CREDENTIALS_PATH=./config/google-credentials.json
GD_VOICEOVER_FOLDER=folder_id_here
GD_IMAGES_FOLDER=folder_id_here
GD_FINALS_FOLDER=folder_id_here

# === AWS S3 ===
S3_ENABLED=false
AWS_REGION=us-east-1
S3_BUCKET=raw-videos
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret

# === Publishing ===
YOUTUBE_ENABLED=false
YOUTUBE_CREDENTIALS_PATH=./config/youtube-credentials.json
YOUTUBE_CATEGORY=28
YOUTUBE_REGION=US

TIKTOK_ENABLED=false
TIKTOK_API_KEY=your_key
TIKTOK_USERNAME=your_username

INSTAGRAM_ENABLED=false
INSTAGRAM_API_KEY=your_key
INSTAGRAM_USERNAME=your_username

# === Google Sheets Tracking ===
SHEETS_ENABLED=false
SHEETS_CREDENTIALS_PATH=./config/google-credentials.json
SHEETS_ID=your_spreadsheet_id
SHEETS_NAME=Sheet1

# === Content ===
CONTENT_KEYWORDS=stoic, ancient rome, roman architecture
CONTENT_THEMES=death,pride,discipline,humility,impermanence,glory,silence,duty,control,time
MAX_WORDS=45

# === Schedule ===
SCHEDULE_ENABLED=false
SCHEDULE_CRON=0 */6 * * *
EOF

# ============================================
# FILE 4: index.js
# ============================================
cat > index.js << 'EOF'
// index.js - Main entry point
const StoicShortsGenerator = require('./src/generator');
const config = require('./config/config');
const logger = require('./src/utils/logger');

async function main() {
  try {
    logger.info('Starting Stoic Shorts automation...');
    const generator = new StoicShortsGenerator(config);
    await generator.run();
    logger.info('Automation completed successfully');
  } catch (error) {
    logger.error('Automation failed:', error);
    process.exit(1);
  }
}

// Run on schedule or immediately
if (config.schedule.enabled) {
  const cron = require('node-cron');
  cron.schedule(config.schedule.cron, main);
  logger.info(`Scheduled to run: ${config.schedule.cron}`);
} else {
  main();
}
EOF

# ============================================
# FILE 5: config/config.js
# ============================================
cat > config/config.js << 'EOF'
// config/config.js
require('dotenv').config();

module.exports = {
  // AI Models
  llm: {
    provider: process.env.LLM_PROVIDER || 'openrouter',
    model: process.env.LLM_MODEL || 'deepseek/deepseek-chat-v3-0324',
    apiKey: process.env.LLM_API_KEY,
    baseUrl: process.env.LLM_BASE_URL || 'https://openrouter.ai/api/v1'
  },

  // Image Generation
  imageGen: {
    type: process.env.IMAGE_GEN_TYPE || 'comfyui',
    comfyui: {
      url: process.env.COMFYUI_URL || 'http://localhost:8188',
      checkpoint: process.env.COMFYUI_CHECKPOINT || 'realisticStockPhoto_v20.safetensors',
      width: parseInt(process.env.IMAGE_WIDTH) || 544,
      height: parseInt(process.env.IMAGE_HEIGHT) || 960,
      steps: parseInt(process.env.IMAGE_STEPS) || 30,
      cfg: parseFloat(process.env.IMAGE_CFG) || 8
    }
  },

  // Voice Generation
  voice: {
    url: process.env.VOICE_URL || 'http://localhost:8880/v1/audio/speech',
    model: process.env.VOICE_MODEL || 'kokoro',
    voice: process.env.VOICE_NAME || 'am_michael'
  },

  // Video Generation
  video: {
    numImages: parseInt(process.env.NUM_IMAGES) || 2,
    outputDir: process.env.VIDEO_OUTPUT_DIR || './data/stoic_shorts',
    transitionStyle: process.env.TRANSITION_STYLE || 'fade'
  },

  // Captions
  captions: {
    enabled: process.env.CAPTIONS_ENABLED !== 'false',
    url: process.env.CAPTION_SERVICE_URL || 'http://localhost:8080/v1/video/caption',
    apiKey: process.env.CAPTION_API_KEY || 'thekey',
    settings: {
      lineColor: process.env.CAPTION_LINE_COLOR || '#FFFFFF',
      wordColor: process.env.CAPTION_WORD_COLOR || 'FFFF00',
      outlineColor: process.env.CAPTION_OUTLINE_COLOR || '#000000',
      allCaps: process.env.CAPTION_ALL_CAPS !== 'false',
      maxWordsPerLine: parseInt(process.env.CAPTION_MAX_WORDS) || 10,
      position: process.env.CAPTION_POSITION || 'bottom_center',
      fontSize: parseInt(process.env.CAPTION_FONT_SIZE) || 96,
      fontFamily: process.env.CAPTION_FONT_FAMILY || 'Arial',
      bold: process.env.CAPTION_BOLD !== 'false'
    }
  },

  // Storage
  storage: {
    googleDrive: {
      enabled: process.env.GOOGLE_DRIVE_ENABLED === 'true',
      credentialsPath: process.env.GOOGLE_CREDENTIALS_PATH || './config/google-credentials.json',
      folders: {
        voiceovers: process.env.GD_VOICEOVER_FOLDER || '1ENYaAnwT4f8O5sr2PVXQqL-Go9TzJQto',
        images: process.env.GD_IMAGES_FOLDER || '1oRjIYchXEVE5PMzx6bL6cmHGlua1UA_B',
        finals: process.env.GD_FINALS_FOLDER || '1AnQ00_qdqVui3Ufh4BOahEYWfPbQ3_P_'
      }
    },
    s3: {
      enabled: process.env.S3_ENABLED === 'true',
      region: process.env.AWS_REGION || 'us-east-1',
      bucket: process.env.S3_BUCKET || 'raw-videos',
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    }
  },

  // Publishing
  publish: {
    youtube: {
      enabled: process.env.YOUTUBE_ENABLED === 'true',
      credentialsPath: process.env.YOUTUBE_CREDENTIALS_PATH || './config/youtube-credentials.json',
      categoryId: process.env.YOUTUBE_CATEGORY || '28',
      regionCode: process.env.YOUTUBE_REGION || 'US'
    },
    tiktok: {
      enabled: process.env.TIKTOK_ENABLED === 'true',
      apiKey: process.env.TIKTOK_API_KEY,
      username: process.env.TIKTOK_USERNAME,
      uploadUrl: process.env.TIKTOK_UPLOAD_URL || 'https://api.upload-post.com/api/upload'
    },
    instagram: {
      enabled: process.env.INSTAGRAM_ENABLED === 'true',
      apiKey: process.env.INSTAGRAM_API_KEY,
      username: process.env.INSTAGRAM_USERNAME,
      uploadUrl: process.env.INSTAGRAM_UPLOAD_URL || 'https://api.upload-post.com/api/upload'
    }
  },

  // Google Sheets tracking
  sheets: {
    enabled: process.env.SHEETS_ENABLED === 'true',
    credentialsPath: process.env.SHEETS_CREDENTIALS_PATH || './config/google-credentials.json',
    spreadsheetId: process.env.SHEETS_ID || '1Rojlh1YfWkpuow18hOtW_j3_Ku43_cG6t-RlSCGj2Lk',
    sheetName: process.env.SHEETS_NAME || 'Sheet1'
  },

  // Content settings
  content: {
    keywords: process.env.CONTENT_KEYWORDS || 'stoic, ancient rome, roman architecture',
    themes: (process.env.CONTENT_THEMES || 'death,pride,discipline,humility,impermanence,glory,silence,duty,control,time').split(','),
    maxWords: parseInt(process.env.MAX_WORDS) || 45
  },

  // Schedule
  schedule: {
    enabled: process.env.SCHEDULE_ENABLED === 'true',
    cron: process.env.SCHEDULE_CRON || '0 */6 * * *'
  }
};
EOF

# ============================================
# FILE 6: config/README.md
# ============================================
cat > config/README.md << 'EOF'
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
EOF

echo "✅ Part 1 complete! Continue with part 2..."
EOF

chmod +x setup.sh
