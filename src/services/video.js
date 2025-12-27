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
      if (error.stderr) {
        logger.error(`FFmpeg stderr: ${error.stderr}`);
      }
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
      if (error.response) {
        let errorData = error.response.data;
        if (error.response.config.responseType === 'arraybuffer') {
          errorData = Buffer.from(errorData).toString();
        }
        logger.error(`Caption addition failed (${error.response.status}): ${JSON.stringify(errorData)}`);
      } else {
        logger.error(`Caption addition failed: ${error.message}`);
      }
      return videoPath;
    }
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = VideoService;
