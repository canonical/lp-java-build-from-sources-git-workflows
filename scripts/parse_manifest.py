#!/usr/bin/env python3
import os
import sys
import urllib.request
import yaml
from pathlib import Path

PRODUCT = sys.argv[1]
VERSION = os.environ["VERSION"]

ROOT_DIR = Path(__file__).parent.parent
PRODUCT_DIR = ROOT_DIR / PRODUCT
MANIFEST_NAME = f"{PRODUCT}-{VERSION}.yml"

OUTPUT_PATH = PRODUCT_DIR / "repos.txt"

manifest_url = f"https://raw.githubusercontent.com/opensearch-project/opensearch-build/{VERSION}/manifests/{VERSION}/{MANIFEST_NAME}"
with urllib.request.urlopen(manifest_url) as response:
    manifest = yaml.safe_load(response.read())

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
