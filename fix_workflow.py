import json

with open("api-workflow.json", "r") as f:
    wf = json.load(f)

# Node 22
wf["22"]["inputs"] = {
  "model": "Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors",
  "base_precision": "fp16",
  "quantization": "fp8_e4m3fn",
  "load_device": "offload_device",
  "attention_mode": "sdpa",
  "lora_device": "default"
}

# Node 349
wf["349"]["inputs"] = {
  "model_name": "wan_2.1_vae.safetensors",
  "dtype": "fp16",
  "force_offload": False,
  "tiled": False
}

# Node 90
wf["90"]["inputs"] = {
  "vitpose_model": "vitpose_h_wholebody_model.onnx",
  "yolo_model": "yolov10m.onnx",
  "onnx_device": "CUDAExecutionProvider"
}

# Node 354
wf["354"]["inputs"] = {
  "lora_0": "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors",
  "strength_0": 1.0,
  "lora_1": "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
  "strength_1": 0.3,
  "lora_2": "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors",
  "strength_2": 0.9,
  "lora_3": "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors",
  "strength_3": 0.5,
  "lora_4": "none",
  "strength_4": 0.0,
  "force_offload": False,
  "fuse_lora": False
}

# Node 271
wf["271"]["inputs"] = {
  "clip_vision": ["59", 0],
  "image_1": ["68", 0],
  "strength_1": 1.0,
  "strength_2": 1.0,
  "crop": "center",
  "combine_embeds": "average",
  "force_offload": True,
  "padding": 0,
  "pad_alpha": 0.5
}

# Node 270
wf["270"]["inputs"] = {
  "vae": ["349", 0],
  "clip_embeds": ["271", 0],
  "ref_images": ["68", 0],
  "pose_images": ["532", 0],
  "face_images": ["89", 1],
  "width": ["309", 1],
  "height": ["309", 2],
  "num_frames": ["75", 1],
  "frame_window_size": 81,
  "colormatch": False,
  "pose_strength": 0.5,
  "face_strength": 0.6,
  "force_offload": False
}

# Node 273
wf["273"]["inputs"] = {
  "model": ["78", 0],
  "image_embeds": ["270", 0],
  "text_embeds": ["490", 0],
  "shift": 4.0,
  "steps": 5,
  "seed": 880367177131732,
  "cfg": 0.75,
  "scheduler": "dpm++_sde",
  "riflex_freq_index": 0,
  "force_offload": False
}

# Node 28
wf["28"]["inputs"] = {
  "vae": ["349", 0],
  "samples": ["273", 0],
  "tiled": False,
  "tile_x": 272,
  "tile_y": 272,
  "tile_stride_x": 144,
  "tile_stride_y": 128,
  "load_device": "default"
}

# Node 532
wf["532"]["inputs"] = {
  "pose_data": ["89", 0],
  "filter_extra_people": True,
  "conf_thresh_body": 0.7,
  "min_run_frames": 12,
  "gap_frames": 2,
  "conf_thresh_hands": 0.2,
  "smooth_alpha": 0.5
}

with open("api-workflow.json", "w") as f:
    json.dump(wf, f, indent=2)
print("api-workflow.json fixed!")
