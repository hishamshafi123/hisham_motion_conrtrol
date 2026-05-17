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
