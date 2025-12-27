#!/bin/bash

# Part 3: Remaining Services and README

echo "📝 Creating remaining files..."

# ============================================
# FILE 11: src/services/video.js
# ============================================
cat > src/services/video.js << 'EOF'
const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');
const axios = require('axios');
const logger = require('../utils/logger');
const execAsync = promisify(exec);

class VideoService {
  constructor(config) {
    this.config = config;
    this.outputDir = path.join(process.cwd(), 'data/stoic_shorts/videos');
  }

  async create(imagePaths, audioPath, duration, filename) {
    await fs.mkdir(this.outputDir, { recursive: true });
    const outputPath = path.join(this.outputDir, `video_${filename}.mp4`);
    const durationPerImage = duration;
    const inputs = imagePaths.map(img => `-loop 1 -t ${durationPerImage} -i "${img}"`).join(' ');
    const filterComplex = this.buildFilterComplex(imagePaths.length, durationPerImage);
    const cmd = `ffmpeg -y ${inputs} -i "${audioPath}" -filter_complex "${filterComplex}" -map "[outv]" -map ${imagePaths.length}:a -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k -pix_fmt yuv420p -shortest "${outputPath}"`;
    try {
      logger.info('Rendering video with ffmpeg...');
      await execAsync(cmd);
      logger.info(`Video created: ${outputPath}`);
      return outputPath;
    } catch (error) {
      logger.error(`Video creation failed: ${error.message}`);
      throw error;
    }
  }

  buildFilterComplex(numImages, duration) {
    if (numImages === 1) {
      return '[0:v]scale=544:960:force_original_aspect_ratio=decrease,pad=544:960:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[outv]';
    }
    const fadeDuration = 1;
    let filter = '';
    for (let i = 0; i < numImages; i++) {
      filter += `[${i}:v]scale=544:960:force_original_aspect_ratio=decrease,pad=544:960:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v${i}];`;
    }
    filter += `[v0]`;
    for (let i = 1; i < numImages; i++) {
      const offset = (duration * i) - fadeDuration;
      filter += `[v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}`;
      if (i < numImages - 1) filter += '[vt' + i + '];[vt' + i + ']';
    }
    filter += '[outv]';
    return filter;
  }

  async addCaptions(videoPath, filename, captionConfig) {
    const s3Url = `http://localhost:9000/raw-videos/video_${filename}.mp4`;
    try {
      const response = await axios.post(captionConfig.url, {
        video_url: s3Url,
        settings: captionConfig.settings,
        replace: [{ find: 'um', replace: '' }, { find: 'like', replace: '' }],
        id: `request-${Date.now()}`,
        language: 'en'
      }, { headers: { 'x-api-key': captionConfig.apiKey } });
      const jobId = response.data.job_id;
      const captionedPath = path.join(this.outputDir, `final_video_${filename}.mp4`);
      const s3CaptionedUrl = `http://localhost:9000/nca-toolkit/${jobId}_captioned.mp4`;
      await this.sleep(5000);
      const videoRes = await axios.get(s3CaptionedUrl, { responseType: 'arraybuffer' });
      await fs.writeFile(captionedPath, videoRes.data);
      logger.info(`Captioned video saved: ${captionedPath}`);
      return captionedPath;
    } catch (error) {
      logger.error(`Caption addition failed: ${error.message}`);
      return videoPath;
    }
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = VideoService;
EOF

# ============================================
# FILE 12: src/services/storage.js
# ============================================
cat > src/services/storage.js << 'EOF'
const { google } = require('googleapis');
const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class StorageService {
  constructor(config) {
    this.config = config;
    if (config.googleDrive.enabled) {
      this.initGoogleDrive(config.googleDrive);
    }
    if (config.s3.enabled) {
      this.initS3(config.s3);
    }
  }

  async initGoogleDrive(config) {
    const credentials = require(path.resolve(config.credentialsPath));
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/drive.file']
    });
    this.drive = google.drive({ version: 'v3', auth });
  }

  initS3(config) {
    this.s3 = new AWS.S3({
      region: config.region,
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey
    });
    this.s3Bucket = config.bucket;
  }

  async uploadToGoogleDrive(filePath, type, filename) {
    if (!this.drive) return;
    const folderMap = {
      voiceover: this.config.googleDrive.folders.voiceovers,
      image: this.config.googleDrive.folders.images,
      final: this.config.googleDrive.folders.finals
    };
    const folderId = folderMap[type];
    const baseName = path.basename(filePath);
    try {
      const response = await this.drive.files.create({
        requestBody: {
          name: type === 'image' ? `Images_${filename}` : baseName,
          parents: [folderId]
        },
        media: { body: fs.createReadStream(filePath) }
      });
      logger.info(`Uploaded to Google Drive: ${response.data.id}`);
      return response.data;
    } catch (error) {
      logger.error(`Google Drive upload failed: ${error.message}`);
      throw error;
    }
  }

  async uploadToS3(filePath, filename) {
    if (!this.s3) return;
    const fileContent = fs.readFileSync(filePath);
    const key = path.basename(filePath);
    try {
      const response = await this.s3.upload({
        Bucket: this.s3Bucket,
        Key: key,
        Body: fileContent
      }).promise();
      logger.info(`Uploaded to S3: ${response.Location}`);
      return response;
    } catch (error) {
      logger.error(`S3 upload failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = StorageService;
EOF

# ============================================
# FILE 13: src/services/publish.js
# ============================================
cat > src/services/publish.js << 'EOF'
const { google } = require('googleapis');
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class PublishService {
  constructor(config) {
    this.config = config;
    if (config.youtube.enabled) {
      this.initYoutube(config.youtube);
    }
  }

  async initYoutube(config) {
    const credentials = require(path.resolve(config.credentialsPath));
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/youtube.upload']
    });
    this.youtube = google.youtube({ version: 'v3', auth });
  }

  async toYoutube(videoPath, title, description) {
    if (!this.youtube) return null;
    try {
      const response = await this.youtube.videos.insert({
        part: 'snippet,status',
        requestBody: {
          snippet: { title, description, categoryId: this.config.youtube.categoryId, tags: this.config.youtube.tags || [] },
          status: { privacyStatus: 'public' }
        },
        media: { body: fs.createReadStream(videoPath) }
      });
      logger.info(`Published to YouTube: ${response.data.id}`);
      return response.data;
    } catch (error) {
      logger.error(`YouTube publish failed: ${error.message}`);
      throw error;
    }
  }

  async toTikTok(videoPath, title) {
    if (!this.config.tiktok.enabled) return null;
    try {
      const form = new FormData();
      form.append('title', title);
      form.append('user', this.config.tiktok.username);
      form.append('platform[]', 'tiktok');
      form.append('video', fs.createReadStream(videoPath));
      const response = await axios.post(this.config.tiktok.uploadUrl, form, {
        headers: { ...form.getHeaders(), 'Authorization': `Apikey ${this.config.tiktok.apiKey}` }
      });
      logger.info('Published to TikTok');
      return response.data;
    } catch (error) {
      logger.error(`TikTok publish failed: ${error.message}`);
      throw error;
    }
  }

  async toInstagram(videoPath, title) {
    if (!this.config.instagram.enabled) return null;
    try {
      const form = new FormData();
      form.append('title', title);
      form.append('user', this.config.instagram.username);
      form.append('platform[]', 'instagram');
      form.append('video', fs.createReadStream(videoPath));
      const response = await axios.post(this.config.instagram.uploadUrl, form, {
        headers: { ...form.getHeaders(), 'Authorization': `Apikey ${this.config.instagram.apiKey}` }
      });
      logger.info('Published to Instagram');
      return response.data;
    } catch (error) {
      logger.error(`Instagram publish failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = PublishService;
EOF

# ============================================
# FILE 14: src/services/sheets.js
# ============================================
cat > src/services/sheets.js << 'EOF'
const { google } = require('googleapis');
const path = require('path');
const logger = require('../utils/logger');

class SheetsService {
  constructor(config) {
    this.config = config;
    this.initSheets(config);
  }

  async initSheets(config) {
    const credentials = require(path.resolve(config.credentialsPath));
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/spreadsheets']
    });
    this.sheets = google.sheets({ version: 'v4', auth });
  }

  async addEntry(data) {
    try {
      const response = await this.sheets.spreadsheets.values.append({
        spreadsheetId: this.config.spreadsheetId,
        range: `${this.config.sheetName}!A:G`,
        valueInputOption: 'USER_ENTERED',
        requestBody: {
          values: [[data.title, data.keywords, data.description, data.script, data.numImages, data.timestamp, data.status]]
        }
      });
      logger.info('Entry added to Google Sheets');
      return response.data;
    } catch (error) {
      logger.error(`Sheets update failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = SheetsService;
EOF

# ============================================
# FILE 15: src/utils/logger.js
# ============================================
cat > src/utils/logger.js << 'EOF'
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.printf(({ timestamp, level, message, stack }) => {
      return `${timestamp} [${level.toUpperCase()}]: ${message}${stack ? '\n' + stack : ''}`;
    })
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message }) => {
          return `${timestamp} ${level}: ${message}`;
        })
      )
    }),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

module.exports = logger;
EOF

# ============================================
# FILE 16: README.md
# ============================================
cat > README.md << 'EOF'
# 🏛️ Stoic Shorts Automation

Automated system for generating, rendering, and publishing Stoic-themed short videos to YouTube, TikTok, and Instagram.

## ✨ Features

- 🤖 AI-powered content generation (story, quote, description)
- 🎨 Image generation via ComfyUI
- 🎙️ Voice synthesis with Kokoro TTS
- 🎬 Automated video creation with transitions
- 📝 Auto-caption generation
- ☁️ Cloud storage (Google Drive, AWS S3)
- 📺 Multi-platform publishing (YouTube, TikTok, Instagram)
- 📊 Google Sheets tracking

## 📋 Prerequisites

- Node.js 18+
- FFmpeg installed and in PATH
- ComfyUI running locally (port 8188)
- Kokoro TTS server (port 8880)
- Caption service (port 8080) - optional

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Setup credentials in config/ directory
# Add google-credentials.json and youtube-credentials.json

# Run
npm start
```

## ⚙️ Configuration

All settings are controlled via `.env` file. See `.env.example` for all options.

## 📁 Project Structure

```
stoic-shorts-automation/
├── config/              # Configuration and credentials
├── src/
│   ├── services/       # AI, Image, Voice, Video, Storage, Publish, Sheets
│   ├── utils/          # Logger
│   └── generator.js    # Main orchestrator
├── data/               # Generated content
├── logs/               # Application logs
└── index.js           # Entry point
```

## 🔄 Workflow

1. Generate stoic content with AI
2. Create voiceover from text
3. Generate themed images
4. Combine into video with transitions
5. Add captions (optional)
6. Upload to cloud storage
7. Publish to social platforms
8. Track in Google Sheets

## 📦 Dependencies

- axios - HTTP client
- googleapis - Google APIs
- aws-sdk - AWS S3
- node-cron - Scheduling
- winston - Logging
- form-data - File uploads
- dotenv - Environment variables

## 🛠️ Troubleshooting

See the full documentation for common issues and solutions.

## 📄 License

MIT
EOF

echo ""
echo "✅ All files created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. npm install"
echo "2. cp .env.example .env"
echo "3. Edit .env with your API keys"
echo "4. Add credentials to config/ directory"
echo "5. npm start"
echo ""
EOF

chmod +x setup_part3.sh
