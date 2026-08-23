#!/usr/bin/env python3
import sys
from pathlib import Path
import yaml


class IndentDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


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

with open(manifest_path) as f:
    data = yaml.safe_load(f)

# remove functionTest component from dashboards (remove this if enabling dashboards tests)
data["components"] = [
    c for c in data["components"] if not c["name"].startswith("functionalTest")
]

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

with open(manifest_path, "w") as f:
    yaml.dump(
        data,
        f,
        Dumper=IndentDumper,
        sort_keys=False,
        indent=2,
    )
