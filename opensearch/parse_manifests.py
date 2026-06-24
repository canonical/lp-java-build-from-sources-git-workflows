#!/usr/bin/env python3
import os
import yaml
from pathlib import Path
import requests

PRODUCT = os.environ["PRODUCT"]
VERSION = os.environ["VERSION"]

ROOT_DIR = Path(__file__).parent.parent
OPENSEARCH_BUILD_DIR = ROOT_DIR / "opensearch-build"
# TODO: Once we can rename "opensearch" folder to "scripts" (mainly last step of PR review) replace path
PRODUCT_DIR = ROOT_DIR / "opensearch" / f"{PRODUCT}-repos"
MANIFEST_NAME = f"{PRODUCT}-{VERSION}.yml"
MANIFEST_REF = f"manifests/{VERSION}/{MANIFEST_NAME}"

OUTPUT_PATH = PRODUCT_DIR / "repos.txt"

# get manifest from upstream opensearch-build repo
response = requests.get(
    f"https://raw.githubusercontent.com/opensearch-project/opensearch-build/refs/heads/main/{MANIFEST_REF}"
)


manifest = yaml.safe_load(response.text)

repos = set()

for component in manifest.get("components", []):
    repo_url = component.get("repository", "")

    if "github.com/opensearch-project/" not in repo_url:
        continue

    repo_name = repo_url.split("/")[-1].replace(".git", "")
    if "functional-test" in repo_name:
        continue
    repos.add(repo_name)

if PRODUCT == "opensearch":
    if "opensearch-prometheus-exporter" not in repos:
        repos.add("opensearch-prometheus-exporter")

    if VERSION.startswith("2."):
        repos.add("performance-analyzer-rca")

# Check if the output directory exists, if not create it
if not PRODUCT_DIR.exists():
    PRODUCT_DIR.mkdir(parents=True)

with open(OUTPUT_PATH, "w") as f:
    f.write("\n".join(sorted(repos)) + "\n")

print(f"{len(repos)} repos written to {OUTPUT_PATH}")