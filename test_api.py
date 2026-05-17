#!/usr/bin/env python3
"""
Motion Forge — RunPod Serverless API Test Client

Usage:
    python test_api.py <input_image> <input_video> [--prompt "description"] [--output output.mp4]

Examples:
    python test_api.py photo.png dance.mp4
    python test_api.py photo.png dance.mp4 --prompt "man dancing in a studio"
    python test_api.py photo.png dance.mp4 --endpoint vmeviwdmth79mz

Requirements:
    pip install requests

Environment variables:
    RUNPOD_API_KEY — your RunPod API key (required)
"""

import argparse
import base64
import json
import os
import sys
import time

import requests

RUNPOD_API_KEY = os.environ.get("RUNPOD_API_KEY", "")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENDPOINT_ID_FILE = os.path.join(SCRIPT_DIR, "endpoint_id.txt")
DEFAULT_WORKFLOW_FILE = os.path.join(SCRIPT_DIR, "api-workflow.json")
POLL_INTERVAL = 5


def get_endpoint_id(cli_endpoint=None):
    """Get endpoint ID from CLI arg, file, or prompt."""
    if cli_endpoint:
        return cli_endpoint
    if os.path.exists(ENDPOINT_ID_FILE):
        with open(ENDPOINT_ID_FILE, "r") as f:
            eid = f.read().strip()
            if eid:
                return eid
    print("❌ No endpoint ID provided.")
    print("   Use --endpoint <id> or create endpoint_id.txt")
    sys.exit(1)


def load_workflow(workflow_path):
    if not os.path.exists(workflow_path):
        print(f"❌ Workflow file not found: {workflow_path}")
        sys.exit(1)
    with open(workflow_path, "r") as f:
        return json.load(f)


def encode_file(file_path):
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    size_mb = os.path.getsize(file_path) / (1024 * 1024)
    print(f"   Encoding {os.path.basename(file_path)} ({size_mb:.1f} MB)...")
    with open(file_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def customize_workflow(workflow, prompt=None):
    """Inject custom prompt into the workflow if provided."""
    if prompt:
        # Node 493 = positive prompt
        if "493" in workflow:
            workflow["493"]["inputs"]["text"] = prompt
            print(f"   ✏️  Positive prompt: {prompt[:80]}...")
    return workflow


def submit_job(endpoint_id, workflow, images):
    url = f"https://api.runpod.ai/v2/{endpoint_id}/run"
    headers = {
        "Authorization": f"Bearer {RUNPOD_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "input": {
            "workflow": workflow,
            "images": images,
        },
        "policy": {
            "executionTimeout": 1800000,  # 30 minutes in ms
        }
    }

    payload_size = len(json.dumps(payload)) / (1024 * 1024)
    print(f"📤 Submitting job ({payload_size:.1f} MB payload)...")

    response = requests.post(url, json=payload, headers=headers, timeout=120)
    if response.status_code != 200:
        print(f"❌ API error {response.status_code}: {response.text[:500]}")
        sys.exit(1)

    data = response.json()
    job_id = data.get("id")
    if not job_id:
        print(f"❌ No job ID in response: {data}")
        sys.exit(1)

    print(f"   ✅ Job submitted: {job_id}")
    return job_id


def poll_status(endpoint_id, job_id):
    url = f"https://api.runpod.ai/v2/{endpoint_id}/status/{job_id}"
    headers = {"Authorization": f"Bearer {RUNPOD_API_KEY}"}

    start_time = time.time()
    last_status = None

    while True:
        try:
            response = requests.get(url, headers=headers, timeout=15)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as e:
            print(f"   ⚠️  Poll error: {e}, retrying...")
            time.sleep(POLL_INTERVAL)
            continue

        status = data.get("status", "UNKNOWN")
        elapsed = time.time() - start_time

        if status != last_status:
            print(f"   [{elapsed:6.1f}s] Status: {status}")
            last_status = status

        if status == "COMPLETED":
            print(f"\n🎉 Job completed in {elapsed:.1f}s")
            return data

        if status in ("FAILED", "CANCELLED", "TIMED_OUT"):
            print(f"\n❌ Job {status} after {elapsed:.1f}s")
            error = data.get("error")
            if error:
                print(f"   Error: {error}")
            output = data.get("output")
            if output:
                print(f"   Output: {json.dumps(output, indent=2)}")
            sys.exit(1)

        time.sleep(POLL_INTERVAL)


def download_output(data, output_path):
    output = data.get("output", {})

    # Try to find video/image URL in output
    video_url = None

    if isinstance(output, dict):
        images = output.get("images", [])
        for img in images:
            url = img.get("data") or img.get("url")
            filename = img.get("filename", "")
            img_type = img.get("type", "")

            if img_type == "s3_url" and url:
                video_url = url
                print(f"   Found S3 output: {filename}")
                break
            elif url and url.startswith("http"):
                video_url = url
                break

    if not video_url and isinstance(output, dict):
        message = output.get("message")
        if message and isinstance(message, str) and message.startswith("http"):
            video_url = message

    if not video_url and isinstance(output, str) and output.startswith("http"):
        video_url = output

    if not video_url:
        # Check if output contains base64 data
        if isinstance(output, dict):
            images = output.get("images", [])
            for img in images:
                if img.get("type") == "base64" and img.get("data"):
                    print("   📦 Output returned as base64, decoding...")
                    raw = base64.b64decode(img["data"])
                    with open(output_path, "wb") as f:
                        f.write(raw)
                    print(f"   ✅ Saved to: {output_path} ({len(raw)/1024:.1f} KB)")
                    return None

        print("⚠️  Could not find a download URL in the output.")
        print(f"   Raw output: {json.dumps(output, indent=2)[:500]}")
        return None

    print(f"📥 Downloading output...")
    print(f"   URL: {video_url[:120]}...")
    response = requests.get(video_url, stream=True, timeout=120)
    response.raise_for_status()

    with open(output_path, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    file_size = os.path.getsize(output_path)
    print(f"   ✅ Saved to: {output_path} ({file_size / 1024:.1f} KB)")
    return video_url


def main():
    parser = argparse.ArgumentParser(
        description="Submit a Motion Forge video generation job to RunPod"
    )
    parser.add_argument("input_image", help="Path to the reference image (PNG/JPG)")
    parser.add_argument("input_video", help="Path to the reference video (MP4)")
    parser.add_argument(
        "--output", "-o", default="output.mp4", help="Output video path (default: output.mp4)"
    )
    parser.add_argument(
        "--prompt", "-p", default=None,
        help="Custom positive prompt (default: uses workflow's built-in prompt)",
    )
    parser.add_argument(
        "--endpoint", "-e", default=None,
        help="RunPod endpoint ID (default: reads from endpoint_id.txt)",
    )
    parser.add_argument(
        "--workflow", "-w", default=DEFAULT_WORKFLOW_FILE,
        help=f"Workflow JSON path (default: api-workflow.json)",
    )
    args = parser.parse_args()

    if not RUNPOD_API_KEY:
        print("❌ RUNPOD_API_KEY environment variable not set.")
        print("   export RUNPOD_API_KEY='rpa_...'")
        sys.exit(1)

    endpoint_id = get_endpoint_id(args.endpoint)
    workflow = load_workflow(args.workflow)
    workflow = customize_workflow(workflow, args.prompt)

    # Encode both image and video as inputs
    print("\n📁 Encoding input files...")
    image_b64 = encode_file(args.input_image)
    video_b64 = encode_file(args.input_video)

    images = [
        {"name": "Ref_Image.png", "image": image_b64},
        {"name": "Ref_Video.mp4", "image": video_b64},
    ]

    print(f"\n{'='*60}")
    print(f"🖼️  Image:    {args.input_image}")
    print(f"🎬 Video:    {args.input_video}")
    print(f"🎯 Endpoint: {endpoint_id}")
    print(f"💾 Output:   {args.output}")
    print(f"{'='*60}\n")

    start_time = time.time()
    job_id = submit_job(endpoint_id, workflow, images)
    result = poll_status(endpoint_id, job_id)
    video_url = download_output(result, args.output)

    total_time = time.time() - start_time
    print()
    print("=" * 60)
    print(f"📊 Summary")
    print(f"   Total time:  {total_time:.1f}s")
    print(f"   Job ID:      {job_id}")
    print(f"   Output file: {args.output}")
    if video_url:
        print(f"   S3 URL:      {video_url[:80]}...")
    print("=" * 60)


if __name__ == "__main__":
    main()
