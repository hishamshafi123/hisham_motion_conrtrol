# Motion Forge 1.0 — RunPod Serverless

Wan2.2 Animate 14B motion transfer — all 10 models baked into a single Docker image for zero-cold-start RunPod serverless deployment.

## Models (10 total)

| # | Model | Size | Path |
|---|-------|------|------|
| 1 | vitpose_h_wholebody_model.onnx | ~411 KB | diffusion_models/ |
| 2 | yolov10m.onnx | ~59 MB | diffusion_models/ |
| 3 | wan_2.1_vae.safetensors | ~242 MB | vae/ |
| 4 | clip_vision_h.safetensors | ~1.2 GB | clip_vision/ |
| 5 | umt5_xxl_fp8_e4m3fn_scaled.safetensors | ~6.3 GB | text_encoders/ |
| 6 | lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors | ~2.8 GB | loras/ |
| 7 | wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors | ~1.2 GB | loras/ |
| 8 | Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors | ~4.6 GB | loras/ |
| 9 | Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors | ~819 MB | loras/ |
| 10 | Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors | ~17 GB | diffusion_models/ |

## Quick Start

### Build locally (requires NVIDIA GPU + ~60GB disk)
```bash
docker build -t motion-forge-worker:v1 . --build-arg HF_TOKEN=$HF_TOKEN
```

### Run locally
```bash
docker run --rm --gpus all -p 8188:8188 motion-forge-worker:v1
```

### Submit a job (Python)
```bash
export RUNPOD_API_KEY='rpa_...'
python test_api.py ref_image.png ref_video.mp4 --output output.mp4
```

## Deployment

### 1. Set GitHub Secrets
Go to your repo → Settings → Secrets and variables → Actions:
- `DOCKERHUB_USERNAME` — Docker Hub username
- `DOCKERHUB_TOKEN` — Docker Hub access token
- `HF_TOKEN` — HuggingFace token (for gated model downloads)

### 2. Push to main
The GitHub Actions workflow will build and push the Docker image automatically.

### 3. Create the RunPod endpoint
```bash
export RUNPOD_API_KEY='rpa_...'
export DOCKERHUB_USERNAME='your_username'
export R2_ACCOUNT_ID='...'
export R2_ACCESS_KEY_ID='...'
export R2_SECRET_ACCESS_KEY='...'
python create_endpoint.py
```

### 4. Test
```bash
python test_api.py my_image.png my_video.mp4
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Build recipe — all 10 models baked in |
| `api-workflow.json` | API-format ComfyUI workflow |
| `workflow.json` | Original UI workflow |
| `analysis.json` | ComfyUI Wizard analysis result |
| `create_endpoint.py` | Create RunPod serverless endpoint |
| `test_api.py` | Submit jobs and download outputs |
| `.github/workflows/build.yml` | CI/CD — auto-build on push to main |

## Architecture
```
Client → POST /run (workflow JSON + base64 image + video)
       → RunPod Serverless
       → Docker image (all models pre-loaded)
       → ComfyUI processes workflow
       → Output video → Cloudflare R2
       → Response returns R2 URL
```

## Cost Estimate
- **L40 (48GB)**: ~$0.76/hr → ~$0.13–0.25/video
- **A40 (48GB)**: ~$0.64/hr → ~$0.11–0.21/video
- **No network volume needed** — models baked into image
- **Active Workers = 0** means no cost when idle
