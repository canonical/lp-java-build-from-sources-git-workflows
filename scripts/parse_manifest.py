#!/usr/bin/env python3
import os
import subprocess
import sys
import yaml
from pathlib import Path

PRODUCT = sys.argv[1]
VERSION = os.environ["VERSION"]

ROOT_DIR = Path(__file__).parent.parent
OPENSEARCH_BUILD_DIR = ROOT_DIR / "opensearch-build"
PRODUCT_DIR = ROOT_DIR / PRODUCT
MANIFEST_NAME = f"{PRODUCT}-{VERSION}.yml"
MANIFEST_REF = f"manifests/{VERSION}/{MANIFEST_NAME}"

OUTPUT_PATH = PRODUCT_DIR / "repos.txt"

# get manifest from upstream tag, in case local manifests already changed
result = subprocess.run(
    ["git", "show", f"{VERSION}:{MANIFEST_REF}"],
    cwd=OPENSEARCH_BUILD_DIR,
    capture_output=True,
    text=True,
    check=True,
)
manifest = yaml.safe_load(result.stdout)

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

with open(OUTPUT_PATH, "w") as f:
    f.write("\n".join(sorted(repos)) + "\n")

print(f"{len(repos)} repos written to {OUTPUT_PATH}")
