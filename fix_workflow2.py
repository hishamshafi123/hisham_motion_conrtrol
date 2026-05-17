import json

with open("api-workflow.json", "r") as f:
    wf = json.load(f)

# Fix colormatch string
wf["270"]["inputs"]["colormatch"] = "disabled"

# Fix enable_vae_tiling
del wf["28"]["inputs"]["tiled"]
wf["28"]["inputs"]["enable_vae_tiling"] = False

with open("api-workflow.json", "w") as f:
    json.dump(wf, f, indent=2)
print("api-workflow.json fixed again!")
