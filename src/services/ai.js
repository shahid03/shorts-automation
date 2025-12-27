const axios = require('axios');
const logger = require('../utils/logger');

class AIService {
  constructor(config) {
    this.config = config;

    if (!config.baseUrl) {
      throw new Error('LLM_BASE_URL is not configured. Please set LLM_BASE_URL in your .env file to your LLM provider\'s API endpoint (e.g., https://openrouter.ai/api/v1 or https://generativelanguage.googleapis.com/v1beta/openai/).');
    }

    if (!config.apiKey) {
      throw new Error('LLM_API_KEY is not configured. Please set it in your .env file.');
    }

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
      if (error.response) {
        logger.error(`AI content generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error('AI content generation failed:', error.message);
      }
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
      if (error.response) {
        logger.error(`Description generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error('Description generation failed:', error.message);
      }
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
      if (error.response) {
        logger.error(`Image prompt generation failed (${error.response.status}): ${JSON.stringify(error.response.data)}`);
      } else {
        logger.error('Image prompt generation failed:', error.message);
      }
      throw error;
    }
  }
}

module.exports = AIService;
