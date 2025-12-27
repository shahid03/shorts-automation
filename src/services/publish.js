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
      if (error.response) {
        logger.error(`YouTube publish failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error(`YouTube publish failed: ${error.message}`);
      }
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
      if (error.response) {
        logger.error(`TikTok publish failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error(`TikTok publish failed: ${error.message}`);
      }
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
      if (error.response) {
        logger.error(`Instagram publish failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error(`Instagram publish failed: ${error.message}`);
      }
      throw error;
    }
  }
}

module.exports = PublishService;
