# 🏛️ Stoic Shorts Automation

An automated pipeline for generating, rendering, and publishing Stoic-themed short videos. This tool leverages local AI services to create original narratives, quotes, voiceovers, and imagery, combining them into polished short-form videos for social media.

## ✨ Features

- **🤖 AI Content Generation:** Uses LLMs (OpenRouter/DeepSeek) to craft unique Stoic stories and quotes set in ancient Rome.
- **🎨 AI Image Generation:** Integrates with **ComfyUI** to generate consistent, themed visuals.
- **🎙️ Voice Synthesis:** Uses **Kokoro TTS** for high-quality, natural-sounding voiceovers.
- **🎬 Automated Editing:** Compiles images and audio with transitions using **FFmpeg**.
- **📝 Smart Captions:** Auto-generates and overlays stylized captions (optional).
- **☁️ Storage:** Supports **MinIO** (S3-compatible) and Google Drive for asset management.
- **📺 Multi-Platform:** Ready for YouTube, TikTok, and Instagram publishing.
- **📊 Tracking:** Logs production data to Google Sheets.

## 🛠️ Architecture

The system operates as a linear pipeline:

1.  **Content:** LLM generates a Title, Story, Quote, and Image Prompts.
2.  **Audio:** TTS engine converts the script to a `.wav` file.
3.  **Visuals:** Image generator renders scenes based on the prompts.
4.  **Assembly:** Video engine stitches images + audio + transitions.
5.  **Post-Processing:** Captions are generated and burned in.
6.  **Archival:** Final assets are uploaded to MinIO/Google Drive.
7.  **Distribution:** Video is published to configured platforms.

## 📋 Prerequisites

Ensure these services are running locally or are accessible:

*   **Node.js** (v18+)
*   **FFmpeg** (Must be in your system PATH)
*   **ComfyUI** (Default: `http://localhost:8188`) - For image generation.
*   **Kokoro TTS API** (Default: `http://localhost:8880`) - For voice generation.
*   **MinIO Server** (Default: `http://localhost:9000`) - For object storage.
*   *(Optional)* **Caption Service** (Default: `http://localhost:8080`)

## 🚀 Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd stoic-shorts-automation
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Environment Configuration:**
    Copy the example file and update it with your keys.
    ```bash
    cp .env.example .env
    ```
    *   **LLM:** Add your `LLM_API_KEY` (e.g., OpenRouter).
    *   **Storage:** Ensure `MINIO_ENDPOINT` matches your local MinIO setup.
    *   **Services:** Verify URLs for ComfyUI and Kokoro.

4.  **Google/YouTube Credentials (Optional):**
    Place your `google-credentials.json` and `youtube-credentials.json` in the `config/` directory if using Drive/YouTube features.

## 🏃 Usage

**Run Manually:**
Generate a single video immediately.
```bash
npm start
```

**Run on Schedule:**
Enable the scheduler in `.env` (`SCHEDULE_ENABLED=true`). The app will keep running and execute tasks based on the cron expression.

## ⚙️ Configuration

Key configuration options in `.env`:

| Category | Variable | Description |
|----------|----------|-------------|
| **AI** | `LLM_API_KEY` | API Key for the LLM provider. |
| **Images** | `COMFYUI_URL` | URL of your ComfyUI instance. |
| **Voice** | `VOICE_URL` | URL of your TTS service. |
| **Storage** | `STORAGE_PROVIDER` | `minio` (default) or `googleDrive`. |
| **MinIO** | `MINIO_ENDPOINT` | Hostname of MinIO (e.g., `localhost`). |
| **MinIO** | `MINIO_BUCKET` | Bucket name for storing videos. |

## 📦 Project Structure

```
stoic-shorts-automation/
├── config/              # Central configuration logic
├── src/
│   ├── generator.js     # Main pipeline controller
│   ├── services/        # Service integrations
│   │   ├── ai.js        # LLM interaction
│   │   ├── image.js     # ComfyUI interaction
│   │   ├── video.js     # FFmpeg composition
│   │   ├── voice.js     # TTS interaction
│   │   ├── storage.js   # MinIO/Drive adapter
│   │   └── publish.js   # Social media APIs
│   └── utils/
├── data/                # Local temp output directory
└── index.js             # Application entry point
```

## 📄 License

MIT