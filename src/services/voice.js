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
