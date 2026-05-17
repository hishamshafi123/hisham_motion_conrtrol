# Motion Forge 1.0 — RunPod Serverless ComfyUI Worker
# Lightweight image — models + custom nodes live on the network volume.
FROM runpod/worker-comfyui:5.8.4-base

# ── Symlink to Network Volume ────────────────────────────────────────────────
# On RunPod serverless workers, the network volume mounts at /runpod-volume.
# On GPU pods (for testing), it mounts at /workspace.
# The start.sh script in the base image handles both paths, but we
# explicitly symlink /comfyui/models and /comfyui/custom_nodes to the
# volume so ComfyUI finds everything at runtime.
#
# All 10 models + 5 custom nodes live on the volume:
#   models/diffusion_models/  → Wan2.2 Animate 14B, vitpose, yolov10m
#   models/text_encoders/     → UMT5 XXL
#   models/clip_vision/       → CLIP Vision H
#   models/vae/               → Wan 2.1 VAE
#   models/loras/             → 4 LoRAs (LightX2V, Pusa, Fun, 4-step)
#   custom_nodes/             → WanVideoWrapper, WanAnimatePreprocess, etc.

# Create a startup script that detects the volume mount point and symlinks
RUN cat > /opt/setup_volume.sh << 'EOF'
#!/bin/bash
# Detect volume mount point (serverless = /runpod-volume, pods = /workspace)
if [ -d "/runpod-volume/ComfyUI/models" ]; then
    VOLUME_PATH="/runpod-volume"
elif [ -d "/workspace/ComfyUI/models" ]; then
    VOLUME_PATH="/workspace"
else
    echo "WARNING: No network volume found at /runpod-volume or /workspace"
    exit 0
fi

echo "Found volume at $VOLUME_PATH — symlinking models and custom_nodes"
rm -rf /comfyui/models /comfyui/custom_nodes
ln -sf $VOLUME_PATH/ComfyUI/models /comfyui/models
ln -sf $VOLUME_PATH/ComfyUI/custom_nodes /comfyui/custom_nodes
EOF
RUN chmod +x /opt/setup_volume.sh

# Inject volume setup into the existing start.sh (runs before ComfyUI starts)
RUN sed -i '1a /opt/setup_volume.sh' /start.sh

# ── Python Dependencies (required by custom nodes) ──────────────────────────
# Must be baked into the image — the base image doesn't run pip on startup.
RUN pip install --no-cache-dir \
    diffusers>=0.30 \
    transformers>=4.45 \
    onnxruntime-gpu \
    opencv-python-headless \
    color-matcher \
    matplotlib \
    imageio-ffmpeg \
    decord \
    einops \
    sentencepiece \
    ftfy \
    moviepy
