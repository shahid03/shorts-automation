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
    this.storage = new StorageService(config);
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

      if (this.storage.storageType) {
        await this.storage.upload(audioPath, 'voiceover', filename);
      }

      logger.info('Generating image prompts...');
      const imagePrompts = await this.ai.generateImagePrompts(content, this.config.video.numImages);

      logger.info(`Generating ${imagePrompts.length} images...`);
      const imagePaths = await this.image.generateImages(imagePrompts, filename);

      if (this.storage.storageType) {
        for (const imgPath of imagePaths) {
          await this.storage.upload(imgPath, 'image', filename);
        }
      }

      logger.info('Creating video...');
      const videoDuration = Math.round(audioDuration / 2);
      const rawVideoPath = await this.video.create(imagePaths, audioPath, videoDuration, filename);

      let finalVideoPath = rawVideoPath;
      if (this.config.captions.enabled) {
        logger.info('Adding captions...');
        if (this.storage.storageType) {
          await this.storage.upload(rawVideoPath, 'raw', filename);
        }
        finalVideoPath = await this.video.addCaptions(rawVideoPath, filename, this.config.captions);
      }

      if (this.storage.storageType) {
        await this.storage.upload(finalVideoPath, 'final', filename);
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
