#!/bin/bash

# Part 2: Service Files

echo "🔧 Creating service files..."

# ============================================
# FILE 7: src/generator.js
# ============================================
cat > src/generator.js << 'EOF'
// src/generator.js
const AIService = require('./services/ai');
const ImageService = require('./services/image');
const VoiceService = require('./services/voice');
const VideoService = require('./services/video');
const StorageService = require('./services/storage');
const PublishService = require('./services/publish');
const SheetsService = require('./services/sheets');
const logger = require('./utils/logger');

class StoicShortsGenerator {
  constructor(config) {
    this.config = config;
    this.ai = new AIService(config.llm);
    this.image = new ImageService(config.imageGen);
    this.voice = new VoiceService(config.voice);
    this.video = new VideoService(config.video);
    this.storage = new StorageService(config.storage);
    this.publish = new PublishService(config.publish);
    this.sheets = config.sheets.enabled ? new SheetsService(config.sheets) : null;
  }

  async run() {
    try {
      logger.info('Generating story and quote...');
      const content = await this.ai.generateContent(this.config.content);
      logger.info(`Generated: ${content.title}`);

      logger.info('Generating description...');
      const description = await this.ai.generateDescription(content, this.config.content.keywords);

      const filename = this.sanitizeFilename(content.title);
      const script = `${content.story}${content.quote}`;

      logger.info('Generating voiceover...');
      const audioPath = await this.voice.generate(script, filename);
      const audioDuration = await this.getAudioDuration(audioPath);

      if (this.config.storage.googleDrive.enabled) {
        await this.storage.uploadToGoogleDrive(audioPath, 'voiceover', filename);
      }

      logger.info('Generating image prompts...');
      const imagePrompts = await this.ai.generateImagePrompts(content, this.config.video.numImages);

      logger.info(`Generating ${imagePrompts.length} images...`);
      const imagePaths = await this.image.generateImages(imagePrompts, filename);

      if (this.config.storage.googleDrive.enabled) {
        for (const imgPath of imagePaths) {
          await this.storage.uploadToGoogleDrive(imgPath, 'image', filename);
        }
      }

      logger.info('Creating video...');
      const videoDuration = Math.round(audioDuration / 2);
      const rawVideoPath = await this.video.create(imagePaths, audioPath, videoDuration, filename);

      let finalVideoPath = rawVideoPath;
      if (this.config.captions.enabled) {
        logger.info('Adding captions...');
        if (this.config.storage.s3.enabled) {
          await this.storage.uploadToS3(rawVideoPath, filename);
        }
        finalVideoPath = await this.video.addCaptions(rawVideoPath, filename, this.config.captions);
      }

      if (this.config.storage.googleDrive.enabled) {
        await this.storage.uploadToGoogleDrive(finalVideoPath, 'final', filename);
      }

      const publishResults = {};
      if (this.config.publish.youtube.enabled) {
        logger.info('Publishing to YouTube...');
        publishResults.youtube = await this.publish.toYoutube(finalVideoPath, content.title, description);
      }
      if (this.config.publish.tiktok.enabled) {
        logger.info('Publishing to TikTok...');
        publishResults.tiktok = await this.publish.toTikTok(finalVideoPath, content.title);
      }
      if (this.config.publish.instagram.enabled) {
        logger.info('Publishing to Instagram...');
        publishResults.instagram = await this.publish.toInstagram(finalVideoPath, content.title);
      }

      if (this.sheets) {
        await this.sheets.addEntry({
          title: content.title,
          keywords: this.config.content.keywords,
          description,
          script,
          numImages: this.config.video.numImages,
          timestamp: new Date().toISOString(),
          status: 'Published'
        });
      }

      logger.info('Generation complete!');
      return { content, filename, publishResults };
    } catch (error) {
      logger.error('Generation failed:', error);
      throw error;
    }
  }

  sanitizeFilename(title) {
    return title
      .toLowerCase()
      .replace(/['\"]/g, '')
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');
  }

  async getAudioDuration(audioPath) {
    const { exec } = require('child_process');
    const { promisify } = require('util');
    const execAsync = promisify(exec);
    const cmd = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${audioPath}"`;
    const { stdout } = await execAsync(cmd);
    return Math.ceil(parseFloat(stdout));
  }
}

module.exports = StoicShortsGenerator;
EOF

# ============================================
# FILE 8: src/services/ai.js
# ============================================
cat > src/services/ai.js << 'EOF'
const axios = require('axios');
const logger = require('../utils/logger');

class AIService {
  constructor(config) {
    this.config = config;
    this.client = axios.create({
      baseURL: config.baseUrl,
      headers: {
        'Authorization': `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json'
      }
    });
  }

  async generateContent(contentConfig) {
    const theme = contentConfig.themes[Math.floor(Math.random() * contentConfig.themes.length)];
    const prompt = `Write a single original stoic quote in the style of Marcus Aurelius or Seneca. Begin with a very short narrative hook (1-2 sentences), set in ancient Rome, followed by a single deep, reflective quote.

Add a short, poetic title (max 5 words) that captures the essence or emotion of the piece.

Theme: ${theme}

Requirements:
- Entire piece (story + quote) must be under ${contentConfig.maxWords} words.
- Use Roman imagery (baths, temples, generals, scrolls, statues, etc).
- Sound timeless, wise, and stoic.
- Written in elevated but clear English.

Output as JSON with three fields:
{
  "title": "<5-word title>",
  "story": "<short narrative setup>",
  "quote": "<stoic reflection>"
}`;

    try {
      const response = await this.client.post('/chat/completions', {
        model: this.config.model,
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' }
      });
      const content = response.data.choices[0].message.content;
      return JSON.parse(content);
    } catch (error) {
      logger.error('AI content generation failed:', error.message);
      throw error;
    }
  }

  async generateDescription(content, keywords) {
    const prompt = `Based on the title, story, and quote, write a catchy YouTube description (max 30 words):

Title: ${content.title}
Story & Quote: ${content.story}, ${content.quote}
Keywords: ${keywords}

Only output the description, no formatting.`;

    try {
      const response = await this.client.post('/chat/completions', {
        model: this.config.model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 100
      });
      return response.data.choices[0].message.content.trim();
    } catch (error) {
      logger.error('Description generation failed:', error.message);
      throw error;
    }
  }

  async generateImagePrompts(content, numImages) {
    const prompt = `Give me ${numImages} detailed prompts to generate images based on this story and quote. The videos are stoic, ancient Rome themed, like Marcus Aurelius and Seneca.

Story: ${content.story}
Quote: ${content.quote}

Only output prompts in this format:
Image Prompt: [detailed prompt]
Image Prompt: [detailed prompt]

No commas or quotation marks in prompts.`;

    try {
      const response = await this.client.post('/chat/completions', {
        model: this.config.model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 500
      });
      const output = response.data.choices[0].message.content;
      const regex = /Image Prompt:\s*(.*?)(?=Image Prompt:|$)/gs;
      const prompts = [];
      let match;
      while ((match = regex.exec(output)) !== null) {
        prompts.push(match[1].trim());
      }
      return prompts;
    } catch (error) {
      logger.error('Image prompt generation failed:', error.message);
      throw error;
    }
  }
}

module.exports = AIService;
EOF

# ============================================
# FILE 9: src/services/image.js
# ============================================
cat > src/services/image.js << 'EOF'
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const logger = require('../utils/logger');

class ImageService {
  constructor(config) {
    this.config = config;
    this.outputDir = path.join(process.cwd(), 'data/stoic_shorts/images');
  }

  async generateImages(prompts, filename) {
    await fs.mkdir(this.outputDir, { recursive: true });
    const imagePaths = [];
    for (let i = 0; i < prompts.length; i++) {
      logger.info(`Generating image ${i + 1}/${prompts.length}...`);
      const imagePath = await this.generateSingleImage(prompts[i], filename, i);
      imagePaths.push(imagePath);
    }
    return imagePaths;
  }

  async generateSingleImage(prompt, filename, index) {
    if (this.config.type === 'comfyui') {
      return this.generateWithComfyUI(prompt, filename, index);
    }
    throw new Error(`Unsupported image generation type: ${this.config.type}`);
  }

  async generateWithComfyUI(prompt, filename, index) {
    const { comfyui } = this.config;
    const seed = Math.floor(Math.random() * 1000000000000000);
    const workflow = {
      prompt: {
        "3": { inputs: { seed, steps: comfyui.steps, cfg: comfyui.cfg, sampler_name: "euler", scheduler: "normal", denoise: 1, model: ["4", 0], positive: ["6", 0], negative: ["7", 0], latent_image: ["5", 0] }, class_type: "KSampler" },
        "4": { inputs: { ckpt_name: comfyui.checkpoint }, class_type: "CheckpointLoaderSimple" },
        "5": { inputs: { width: comfyui.width, height: comfyui.height, batch_size: 1 }, class_type: "EmptyLatentImage" },
        "6": { inputs: { text: prompt, clip: ["4", 1] }, class_type: "CLIPTextEncode" },
        "7": { inputs: { text: "text, watermark, unrealistic, saturated, high contrast, big nose, painting, drawing, sketch, cartoon, anime, manga, render, CG, 3d, watermark, signature, label", clip: ["4", 1] }, class_type: "CLIPTextEncode" },
        "8": { inputs: { samples: ["3", 0], vae: ["4", 2] }, class_type: "VAEDecode" },
        "9": { inputs: { filename_prefix: "ComfyUI", images: ["8", 0] }, class_type: "SaveImage" }
      }
    };
    try {
      const response = await axios.post(`${comfyui.url}/prompt`, workflow, { headers: { 'Content-Type': 'application/json' } });
      const promptId = response.data.prompt_id;
      await this.sleep(10000);
      const historyRes = await axios.get(`${comfyui.url}/history/${promptId}`);
      const historyData = historyRes.data[promptId];
      const imageFilename = historyData.outputs['9'].images[0].filename;
      const imageUrl = `${comfyui.url}/view?filename=${encodeURIComponent(imageFilename)}&type=output`;
      await this.sleep(1000);
      const imageRes = await axios.get(imageUrl, { responseType: 'arraybuffer' });
      const outputPath = path.join(this.outputDir, `images_${filename}_${index}.png`);
      await fs.writeFile(outputPath, imageRes.data);
      logger.info(`Image saved: ${outputPath}`);
      return outputPath;
    } catch (error) {
      logger.error(`ComfyUI generation failed: ${error.message}`);
      throw error;
    }
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = ImageService;
EOF

# ============================================
# FILE 10: src/services/voice.js
# ============================================
cat > src/services/voice.js << 'EOF'
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const logger = require('../utils/logger');

class VoiceService {
  constructor(config) {
    this.config = config;
    this.outputDir = path.join(process.cwd(), 'data/stoic_shorts/voiceovers');
  }

  async generate(text, filename) {
    await fs.mkdir(this.outputDir, { recursive: true });
    try {
      const response = await axios.post(this.config.url, {
        model: this.config.model,
        input: text,
        voice: this.config.voice
      }, { responseType: 'arraybuffer' });
      const outputPath = path.join(this.outputDir, `audio_${filename}.mp3`);
      await fs.writeFile(outputPath, response.data);
      logger.info(`Voiceover saved: ${outputPath}`);
      return outputPath;
    } catch (error) {
      logger.error(`Voice generation failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = VoiceService;
EOF

echo "✅ Part 2 complete! Continue with part 3..."
EOF

chmod +x setup_part2.sh
