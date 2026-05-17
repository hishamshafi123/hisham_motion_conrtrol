# Motion Forge 1.0 — RunPod Serverless ComfyUI Worker
# Lightweight image: Custom nodes baked in, models loaded from network volume.
FROM runpod/worker-comfyui:5.8.4-base

# ── 1. Custom Nodes (Baked into Image) ───────────────────────────────────────
# We bake the custom nodes into the image to ensure they are always present 
# and never rely on network volume symlinks for code execution.
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper /comfyui/custom_nodes/ComfyUI-WanVideoWrapper && \
    cd /comfyui/custom_nodes/ComfyUI-WanVideoWrapper && git checkout 761b1d191e50d589465e31dc0d40ff7c59b1b7b0 || true

RUN git clone https://github.com/kijai/ComfyUI-KJNodes /comfyui/custom_nodes/ComfyUI-KJNodes && \
    cd /comfyui/custom_nodes/ComfyUI-KJNodes && git checkout ad37ce656c13e9abea002b46e3a89be3dba32355 || true

RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite /comfyui/custom_nodes/ComfyUI-VideoHelperSuite && \
    cd /comfyui/custom_nodes/ComfyUI-VideoHelperSuite && git checkout 8550981384301e9bc5bfea83e5c2c75258102593 || true

RUN git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess /comfyui/custom_nodes/ComfyUI-WanAnimatePreprocess && \
    cd /comfyui/custom_nodes/ComfyUI-WanAnimatePreprocess && git checkout 1a35b81a418bbba093356ad19b19bf2a76a24f4e || true

RUN comfy node install --exit-on-fail comfyui-wanvideowrapper@1.4.5 --mode remote || \
    comfy node install --exit-on-fail comfyui-wanvideowrapper --mode remote

RUN git clone https://github.com/rgthree/rgthree-comfy /comfyui/custom_nodes/rgthree-comfy || true

RUN git clone https://github.com/teskor-hub/comfyui-teskors-utils /comfyui/custom_nodes/comfyui-teskors-utils

# ── 2. Python Dependencies ───────────────────────────────────────────────────
# Find and install all requirements from the custom nodes we just cloned
RUN find /comfyui/custom_nodes -name "requirements.txt" -exec uv pip install -r {} \; || \
    find /comfyui/custom_nodes -name "requirements.txt" -exec pip install -r {} \;

# Also ensure any other missing packages are installed
RUN uv pip install --no-cache-dir \
    diffusers>=0.33.0 \
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
    moviepy \
    accelerate>=1.2.1 \
    peft>=0.17.0 \
    protobuf \
    pyloudnorm \
    gguf>=0.17.1 \
    scipy

# ── 3. Extra Model Paths ─────────────────────────────────────────────────────
# This tells ComfyUI to search for models on the network volume automatically
# without needing symlinks or startup scripts.
RUN cat > /comfyui/extra_model_paths.yaml << 'EOF'
runpod_volume:
    base_path: /runpod-volume/ComfyUI/models
    checkpoints: checkpoints
    clip: clip
    clip_vision: clip_vision
    configs: configs
    controlnet: controlnet
    diffusion_models: diffusion_models
    embeddings: embeddings
    loras: loras
    upscale_models: upscale_models
    vae: vae
    text_encoders: text_encoders
    detection: detection

workspace_volume:
    base_path: /workspace/ComfyUI/models
    checkpoints: checkpoints
    clip: clip
    clip_vision: clip_vision
    configs: configs
    controlnet: controlnet
    diffusion_models: diffusion_models
    embeddings: embeddings
    loras: loras
    upscale_models: upscale_models
    vae: vae
    text_encoders: text_encoders
    detection: detection
EOF

# ── 4. Runtime Volume Symlink ─────────────────────────────────────────────────
# Some custom nodes (OnnxDetectionModelLoader) scan /comfyui/models/detection/
# directly rather than using extra_model_paths.yaml. We create a startup script
# that symlinks the detection folder from the network volume at runtime.
RUN cat > /opt/setup_volume.sh << 'SETUP'
#!/bin/bash
echo "[setup_volume] Detecting network volume..."

# Detect volume mount point
if [ -d "/runpod-volume/ComfyUI/models" ]; then
    VOL="/runpod-volume"
elif [ -d "/workspace/ComfyUI/models" ]; then
    VOL="/workspace"
else
    echo "[setup_volume] WARNING: No network volume found"
    exit 0
fi

echo "[setup_volume] Found volume at $VOL"

# Symlink detection models (ONNX files)
if [ -d "$VOL/ComfyUI/models/detection" ]; then
    mkdir -p /comfyui/models/detection
    ln -sf $VOL/ComfyUI/models/detection/*.onnx /comfyui/models/detection/ 2>/dev/null
    echo "[setup_volume] Linked detection models: $(ls /comfyui/models/detection/)"
fi

# Symlink all other model folders that might be missing
for folder in diffusion_models loras vae clip_vision text_encoders checkpoints; do
    if [ -d "$VOL/ComfyUI/models/$folder" ] && [ ! -L "/comfyui/models/$folder" ]; then
        # Don't replace if folder has content already
        if [ -z "$(ls -A /comfyui/models/$folder 2>/dev/null)" ]; then
            rm -rf /comfyui/models/$folder
            ln -sf $VOL/ComfyUI/models/$folder /comfyui/models/$folder
            echo "[setup_volume] Linked $folder"
        fi
    fi
done

echo "[setup_volume] Done!"
SETUP
RUN chmod +x /opt/setup_volume.sh

# Inject into start.sh so it runs before ComfyUI
RUN sed -i '1a /opt/setup_volume.sh' /start.sh

# ── 5. Patch handler to support VHS_VideoCombine 'gifs' output ────────────────
# The official handler only processes node outputs under the "images" key.
# VHS_VideoCombine outputs video files under "gifs". This patch merges both.
RUN sed -i 's/if "images" in node_output:/# Merge images + gifs (VHS_VideoCombine outputs video as "gifs")\n            all_media = node_output.get("images", []) + node_output.get("gifs", [])\n            if all_media:/' /handler.py && \
    sed -i 's/for image_info in node_output\["images"\]:/for image_info in all_media:/' /handler.py
