#!/usr/bin/env python3
"""
Create the RunPod serverless endpoint for Motion Forge via GraphQL API.

Usage:
    export RUNPOD_API_KEY='rpa_...'
    export DOCKERHUB_USERNAME='your_username'
    export R2_ACCOUNT_ID='...'
    export R2_ACCESS_KEY_ID='...'
    export R2_SECRET_ACCESS_KEY='...'
    python create_endpoint.py
"""

import json, os, sys, requests

RUNPOD_API_KEY = os.environ.get("RUNPOD_API_KEY", "")
DOCKERHUB_USERNAME = os.environ.get("DOCKERHUB_USERNAME", "")
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "")
R2_ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID", "")
R2_SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY", "")

GRAPHQL_URL = "https://api.runpod.io/graphql"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENDPOINT_ID_FILE = os.path.join(SCRIPT_DIR, "endpoint_id.txt")


def gql(query, variables=None):
    headers = {"Authorization": f"Bearer {RUNPOD_API_KEY}", "Content-Type": "application/json"}
    payload = {"query": query}
    if variables:
        payload["variables"] = variables
    r = requests.post(GRAPHQL_URL, json=payload, headers=headers, timeout=30)
    r.raise_for_status()
    data = r.json()
    if "errors" in data:
        print(f"❌ GraphQL errors: {json.dumps(data['errors'], indent=2)}")
        sys.exit(1)
    return data.get("data", {})


def main():
    missing = [n for n, v in [
        ("RUNPOD_API_KEY", RUNPOD_API_KEY), ("DOCKERHUB_USERNAME", DOCKERHUB_USERNAME),
        ("R2_ACCOUNT_ID", R2_ACCOUNT_ID),
        ("R2_ACCESS_KEY_ID", R2_ACCESS_KEY_ID), ("R2_SECRET_ACCESS_KEY", R2_SECRET_ACCESS_KEY),
    ] if not v]
    if missing:
        print("❌ Missing env vars: " + ", ".join(missing))
        sys.exit(1)

    # Lookup GPUs — need 48GB+ for 14B model
    print("🔍 Looking up GPU types...")
    gpus = gql("query { gpuTypes { id displayName memoryInGb } }").get("gpuTypes", [])
    gpu_ids = []
    for g in gpus:
        name = g.get("displayName", "").upper()
        mem = g.get("memoryInGb", 0)
        if ("L40" in name or "A40" in name or "A6000" in name) and mem >= 48:
            gpu_ids.append(g["id"])
    if not gpu_ids:
        print("❌ No suitable GPUs found (need ≥48GB)")
        for g in gpus:
            print(f"  {g['id']}: {g['displayName']} ({g.get('memoryInGb')}GB)")
        sys.exit(1)
    print(f"   GPUs: {gpu_ids}")

    # Create endpoint — NO network volume needed (models baked into image)
    image = f"{DOCKERHUB_USERNAME}/motion-forge-worker:v1"
    bucket_url = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    print(f"\n🚀 Creating endpoint 'motion-forge-api' with image {image}...")

    mutation = """
    mutation saveEndpoint($input: EndpointInput!) {
        saveEndpoint(input: $input) { id name status }
    }"""
    variables = {"input": {
        "name": "motion-forge-api", "imageName": image,
        "gpuIds": ",".join(gpu_ids),
        "volumeInGb": 20, "workersMax": 5, "workersMin": 0,
        "idleTimeout": 30, "executionTimeoutMs": 1800000,
        "env": [
            {"key": "BUCKET_ENDPOINT_URL", "value": bucket_url},
            {"key": "BUCKET_ACCESS_KEY_ID", "value": R2_ACCESS_KEY_ID},
            {"key": "BUCKET_SECRET_ACCESS_KEY", "value": R2_SECRET_ACCESS_KEY},
            {"key": "BUCKET_NAME", "value": "comfyui-outputs"},
            {"key": "REFRESH_WORKER", "value": "false"},
        ],
    }}

    result = gql(mutation, variables)
    ep = result.get("saveEndpoint", {})
    ep_id = ep.get("id")
    if not ep_id:
        print(f"❌ Failed: {json.dumps(result, indent=2)}")
        sys.exit(1)

    with open(ENDPOINT_ID_FILE, "w") as f:
        f.write(ep_id)
    print(f"✅ Endpoint created: {ep_id}")
    print(f"💾 Saved to {ENDPOINT_ID_FILE}")
    print(f"🔗 API URL: https://api.runpod.ai/v2/{ep_id}/run")


if __name__ == "__main__":
    main()
