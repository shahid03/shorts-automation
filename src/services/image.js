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
      
      // Poll for completion
      let historyData = null;
      let attempts = 0;
      const maxAttempts = 120; // Wait up to 2 minutes
      
      while (!historyData && attempts < maxAttempts) {
        attempts++;
        await this.sleep(1000);
        try {
          const historyRes = await axios.get(`${comfyui.url}/history/${promptId}`);
          historyData = historyRes.data[promptId];
        } catch (e) {
          // Ignore errors during polling, might be temporary
        }
      }

      if (!historyData) {
        throw new Error('Timeout waiting for ComfyUI generation');
      }

      const imageFilename = historyData.outputs['9'].images[0].filename;
      const imageUrl = `${comfyui.url}/view?filename=${encodeURIComponent(imageFilename)}&type=output`;
      await this.sleep(1000);
      const imageRes = await axios.get(imageUrl, { responseType: 'arraybuffer' });
      const outputPath = path.join(this.outputDir, `images_${filename}_${index}.png`);
      await fs.writeFile(outputPath, imageRes.data);
      logger.info(`Image saved: ${outputPath}`);
      return outputPath;
    } catch (error) {
      if (error.response) {
        logger.error(`ComfyUI generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error(`ComfyUI generation failed: ${error.message}`);
      }
      throw error;
    }
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = ImageService;
