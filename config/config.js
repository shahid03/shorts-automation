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
    provider: process.env.STORAGE_PROVIDER || 'minio',
    googleDrive: {
      enabled: process.env.GOOGLE_DRIVE_ENABLED === 'true',
      credentialsPath: process.env.GOOGLE_CREDENTIALS_PATH || './config/google-credentials.json',
      folders: {
        voiceovers: process.env.GD_VOICEOVER_FOLDER || '1ENYaAnwT4f8O5sr2PVXQqL-Go9TzJQto',
        images: process.env.GD_IMAGES_FOLDER || '1oRjIYchXEVE5PMzx6bL6cmHGlua1UA_B',
        finals: process.env.GD_FINALS_FOLDER || '1AnQ00_qdqVui3Ufh4BOahEYWfPbQ3_P_'
      }
    },
    minio: {
      enabled: process.env.MINIO_ENABLED === 'true',
      endpoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: parseInt(process.env.MINIO_PORT) || 9000,
      bucket: process.env.MINIO_BUCKET || 'raw-videos',
      accessKeyId: process.env.MINIO_ACCESS_KEY_ID,
      secretAccessKey: process.env.MINIO_SECRET_ACCESS_KEY,
      useSSL: process.env.MINIO_USE_SSL === 'true'
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
