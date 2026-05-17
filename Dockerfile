# Motion Forge 1.0 — RunPod Serverless ComfyUI Worker
# Lightweight image — models + custom nodes live on the network volume.
FROM runpod/worker-comfyui:5.8.4-base

# ── Symlink to Network Volume ────────────────────────────────────────────────
# Replace the default models/ and custom_nodes/ with symlinks to the network
# volume at /runpod-volume. All 10 models + 5 custom nodes live there.
RUN rm -rf /comfyui/models /comfyui/custom_nodes && \
    ln -sf /runpod-volume/ComfyUI/models /comfyui/models && \
    ln -sf /runpod-volume/ComfyUI/custom_nodes /comfyui/custom_nodes

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
