# 🏛️ Stoic Shorts Automation

An automated pipeline for generating, rendering, and publishing Stoic-themed short videos. This tool leverages AI services (Local or Cloud) to create original narratives, quotes, voiceovers, and imagery, combining them into polished short-form videos for social media.

## ✨ Features

- **🤖 AI Content Generation:** Uses LLMs (OpenRouter/DeepSeek) to craft unique Stoic stories and quotes set in ancient Rome.
- **🎨 AI Image Generation:** Integrates with **ComfyUI** (running locally or on Google Colab) to generate consistent, themed visuals.
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

Ensure these services are running locally or are accessible remotely:

*   **Node.js** (v18+)
*   **FFmpeg** (Must be in your system PATH)
*   **ComfyUI** - For image generation.
    *   *Option A (Local):* Running at `http://localhost:8188`
    *   *Option B (Cloud):* Running on Google Colab via Cloudflare Tunnel (see setup below).
*   **Kokoro TTS API** (Default: `http://localhost:8880`) - For voice generation.
*   **MinIO Server** (Default: `http://localhost:9000`) - For object storage.
*   *(Optional)* **Caption Service** (Default: `http://localhost:8080`)

## 🚀 Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd shorts-automation
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
    *   **Services:** Update `COMFYUI_URL` and `VOICE_URL` based on your setup.

4.  **Google/YouTube Credentials (Optional):**
    Place your `google-credentials.json` and `youtube-credentials.json` in the `config/` directory if using Drive/YouTube features.

## 🌩️ Running ComfyUI on Google Colab (Recommended for Mac/Low-VRAM)

If you don't want to run ComfyUI locally or face memory issues, use Google Colab with a Cloudflare Tunnel:

1.  **Open Google Colab:** Create a new notebook with a GPU runtime (Runtime > Change runtime type > T4 GPU).
2.  **Run the Setup Script:** Paste and run the following code in a cell:
    ```python
    import os, time, subprocess
    
    # 1. Install ComfyUI & Dependencies
    !git clone https://github.com/comfyanonymous/ComfyUI
    %cd ComfyUI
    !pip install -r requirements.txt
    
    # 2. Download Model (Realistic Stock Photo v2.0)
    !wget -O models/checkpoints/realisticStockPhoto_v20.safetensors https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/realisticStockPhoto_v20.safetensors
    
    # 3. Install Cloudflared
    !wget -q -nc https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    !dpkg -i cloudflared-linux-amd64.deb
    
    # 4. Start ComfyUI
    subprocess.Popen(["python", "main.py", "--port", "8188"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(10)
    
    # 5. Start Tunnel
    !cloudflared tunnel --url http://127.0.0.1:8188
    ```
3.  **Get the URL:** Copy the `https://...trycloudflare.com` URL from the output.
4.  **Update .env:**
    ```bash
    COMFYUI_URL=https://your-tunnel-url.trycloudflare.com
    COMFYUI_CHECKPOINT=realisticStockPhoto_v20.safetensors
    ```

## 🏃 Usage

**Run Manually:**
Generate a single video immediately.
```bash
npm start
```

**Run on Schedule:**
Enable the scheduler in `.env` (`SCHEDULE_ENABLED=true`). The app will keep running and execute tasks based on the cron expression.

## 🔧 Troubleshooting

### Local Execution Note
If choosing to run locally, ensure you have sufficient storage and VRAM for `realisticStockPhoto_v20.safetensors` (~7GB). Mac users may need `export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0` to avoid memory errors.

### ComfyUI Timeout / "Cannot read properties of undefined"
If image generation fails with a timeout or undefined error:
1.  Ensure your `COMFYUI_URL` is correct and accessible.
2.  If using Colab, ensure the instance hasn't disconnected (check if the cell is still running).
3.  The system now polls for completion for up to 2 minutes. For very complex prompts or slow GPUs, this might need adjustment in `src/services/image.js`.

## ⚙️ Configuration

Key configuration options in `.env`:

| Category | Variable | Description |
|----------|----------|-------------|
| **AI** | `LLM_API_KEY` | API Key for the LLM provider. |
| **Images** | `COMFYUI_URL` | URL of your ComfyUI instance (Local or Cloudflare). |
| **Voice** | `VOICE_URL` | URL of your TTS service. |
| **Storage** | `STORAGE_PROVIDER` | `minio` (default) or `googleDrive`. |
| **MinIO** | `MINIO_ENDPOINT` | Hostname of MinIO (e.g., `localhost`). |
| **MinIO** | `MINIO_BUCKET` | Bucket name for storing videos. |

## 📦 Project Structure

```
shorts-automation/
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