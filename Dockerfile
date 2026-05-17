# Motion Forge 1.0 — RunPod Serverless ComfyUI Worker
# All 10 models baked into the image for zero-cold-start serverless execution.
FROM runpod/worker-comfyui:5.8.4-base

# Build-time token for gated HuggingFace downloads
ARG HF_TOKEN=""

# ── Custom Nodes ─────────────────────────────────────────────────────────────
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper /comfyui/custom_nodes/ComfyUI-WanVideoWrapper && \
    cd /comfyui/custom_nodes/ComfyUI-WanVideoWrapper && \
    (git checkout 761b1d191e50d589465e31dc0d40ff7c59b1b7b0 2>/dev/null || \
     (git fetch origin 761b1d191e50d589465e31dc0d40ff7c59b1b7b0 --depth=1 && \
      git checkout 761b1d191e50d589465e31dc0d40ff7c59b1b7b0) || \
     echo "WARN: falling back to default branch HEAD")

RUN git clone https://github.com/kijai/ComfyUI-KJNodes /comfyui/custom_nodes/ComfyUI-KJNodes && \
    cd /comfyui/custom_nodes/ComfyUI-KJNodes && \
    (git checkout ad37ce656c13e9abea002b46e3a89be3dba32355 2>/dev/null || \
     (git fetch origin ad37ce656c13e9abea002b46e3a89be3dba32355 --depth=1 && \
      git checkout ad37ce656c13e9abea002b46e3a89be3dba32355) || \
     echo "WARN: falling back to default branch HEAD")

RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite /comfyui/custom_nodes/ComfyUI-VideoHelperSuite && \
    cd /comfyui/custom_nodes/ComfyUI-VideoHelperSuite && \
    (git checkout 8550981384301e9bc5bfea83e5c2c75258102593 2>/dev/null || \
     (git fetch origin 8550981384301e9bc5bfea83e5c2c75258102593 --depth=1 && \
      git checkout 8550981384301e9bc5bfea83e5c2c75258102593) || \
     echo "WARN: falling back to default branch HEAD")

RUN git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess /comfyui/custom_nodes/ComfyUI-WanAnimatePreprocess && \
    cd /comfyui/custom_nodes/ComfyUI-WanAnimatePreprocess && \
    (git checkout 1a35b81a418bbba093356ad19b19bf2a76a24f4e 2>/dev/null || \
     (git fetch origin 1a35b81a418bbba093356ad19b19bf2a76a24f4e --depth=1 && \
      git checkout 1a35b81a418bbba093356ad19b19bf2a76a24f4e) || \
     echo "WARN: falling back to default branch HEAD")

RUN comfy node install --exit-on-fail comfyui-wanvideowrapper@1.4.5 --mode remote || \
    (echo "WARN: comfyui-wanvideowrapper@1.4.5 unavailable, falling back to latest" >&2 && \
     comfy node install --exit-on-fail comfyui-wanvideowrapper --mode remote)

RUN comfy node install --exit-on-fail rgthree-comfy

RUN git clone https://github.com/teskor-hub/comfyui-teskors-utils /comfyui/custom_nodes/comfyui-teskors-utils

# ── Python Dependencies (required by custom nodes) ──────────────────────────
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

# ── Model Downloads (10 models total) ───────────────────────────────────────
# Helper: retry up to 5 times with backoff
# Model 1: VitPose ONNX (detection) → diffusion_models (where WanAnimatePreprocess looks)
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx' \
      --relative-path models/diffusion_models \
      --filename 'vitpose_h_wholebody_model.onnx' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 2: YOLOv10m ONNX (detection) → diffusion_models
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx' \
      --relative-path models/diffusion_models \
      --filename 'yolov10m.onnx' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 3: Wan 2.1 VAE → vae/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors' \
      --relative-path models/vae \
      --filename 'wan_2.1_vae.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 4: CLIP Vision H → clip_vision/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors' \
      --relative-path models/clip_vision \
      --filename 'clip_vision_h.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 5: UMT5 XXL Text Encoder (FP8) → text_encoders/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors' \
      --relative-path models/text_encoders \
      --filename 'umt5_xxl_fp8_e4m3fn_scaled.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 6: LightX2V distill LoRA → loras/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors' \
      --relative-path models/loras \
      --filename 'lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 7: Wan2.2 I2V LightX2V 4-step LoRA → loras/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors' \
      --relative-path models/loras \
      --filename 'wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 8: Pusa V1 LoRA → loras/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors' \
      --relative-path models/loras \
      --filename 'Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 9: Wan2.2 Fun A14B InP LoRA → loras/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/dci05049/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors' \
      --relative-path models/loras \
      --filename 'Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Model 10: Wan2.2 Animate 14B Diffusion Model (FP8) → diffusion_models/
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do \
    HF_TOKEN=$HF_TOKEN comfy model download \
      --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp8_e4m3fn.safetensors' \
      --relative-path models/diffusion_models \
      --filename 'Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors' && break; \
    if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; \
    SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && \
    echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
