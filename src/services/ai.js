const axios = require("axios");
const logger = require("../utils/logger");

class AIService {
  constructor(config) {
    this.config = config;
    this.client = axios.create({
      baseURL: config.baseUrl,
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json",
      },
    });
  }

  async generateContent(contentConfig) {
    const theme =
      contentConfig.themes[
        Math.floor(Math.random() * contentConfig.themes.length)
      ];
    const basePrompt = contentConfig.promptTemplate.replace("{theme}", theme);
    const prompt = `${basePrompt}

Requirements:
- Entire piece must be under ${contentConfig.maxWords} words.
- Sound timeless, wise, and appropriate for the theme.
- Written in elevated but clear English.

Output as JSON with two fields:
{
  "title": "<short catchy title>",
  "script": "<the full text to be spoken in the video>"
}`;

    try {
      const response = await this.client.post("/chat/completions", {
        model: this.config.model,
        messages: [{ role: "user", content: prompt }],
        response_format: { type: "json_object" },
      });
      const content = response.data.choices[0].message.content;
      return JSON.parse(content);
    } catch (error) {
      if (error.response) {
        logger.error(
          `AI content generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`,
        );
      } else {
        logger.error("AI content generation failed:", error.message);
      }
      throw error;
    }
  }

  async generateDescription(content, keywords) {
    const prompt = `Based on the title and script, write a catchy YouTube description (max 30 words):

Title: ${content.title}
Script: ${content.script}
Keywords: ${keywords}

Only output the description, no formatting.`;

    try {
      const response = await this.client.post("/chat/completions", {
        model: this.config.model,
        messages: [{ role: "user", content: prompt }],
        max_tokens: 100,
      });
      return response.data.choices[0].message.content.trim();
    } catch (error) {
      if (error.response) {
        logger.error(
          `Description generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`,
        );
      } else {
        logger.error("Description generation failed:", error.message);
      }
      throw error;
    }
  }

  async generateImagePrompts(content, numImages) {
    const prompt = `Give me ${numImages} detailed prompts to generate images based on this script.

Style: ${this.config.imageStylePrompt || "cinematic lighting, ultra-realistic"}

Script: ${content.script}

Only output prompts in this format:
Image Prompt: [detailed prompt]
Image Prompt: [detailed prompt]

No commas or quotation marks in prompts.`;

    try {
      const response = await this.client.post("/chat/completions", {
        model: this.config.model,
        messages: [{ role: "user", content: prompt }],
        max_tokens: 500,
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
      if (error.response) {
        logger.error(
          `Image prompt generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`,
        );
      } else {
        logger.error("Image prompt generation failed:", error.message);
      }
      throw error;
    }
  }
}

module.exports = AIService;
