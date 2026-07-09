#!/usr/bin/env python3
import sys
from pathlib import Path
from ruamel.yaml import YAML

if len(sys.argv) < 5:
    print(
        f"Missing expected args: {sys.argv[0]} <product> <version> <prefix> <lp_remote>"
    )
    sys.exit(1)

product, version, prefix, lp_remote = sys.argv[1:5]

root = Path(__file__).parent.parent
manifest_path = (
    root / f"repos/opensearch-build/manifests/{version}/{product}-{version}.yml"
)

yaml = YAML()
yaml.preserve_quotes = True
data = yaml.load(manifest_path)

# remove functionTest component from dashboards (remove this if enabling dashboards tests)
data["components"] = [c for c in data["components"] if c["name"] != "functionalTest"]

for comp in data["components"]:
    repo = comp.get("repository")
    if "github.com/opensearch-project/" not in repo:
        continue

    name = repo.split("/")[-1].replace(".git", "").lower()
    if product == "opensearch" and not name.startswith("opensearch"):
        name = f"opensearch-{name}"

    comp["repository"] = f"{lp_remote}/{name}"

    # main repos use non-dotted tags, plugins use dotted
    if comp["name"] in ("OpenSearch", "OpenSearch-Dashboards"):
        comp["ref"] = f"tags/{prefix}-v{version}"
    else:
        comp["ref"] = f"tags/{prefix}-v{version}.0"

# add prometheus-exporter for opensearch
if product == "opensearch":
    if "prometheus-exporter" not in {c["name"] for c in data["components"]}:
        data["components"].append(
            {
                "name": "prometheus-exporter",
                "repository": f"{lp_remote}/opensearch-prometheus-exporter",
                "ref": f"tags/{prefix}-v{version}.0",
                "platforms": ["linux", "windows"],
            }
        )

yaml.dump(data, manifest_path)
