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
