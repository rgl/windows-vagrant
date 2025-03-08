#!/bin/bash
# this updates the local windows-evaluation-isos.json file from the data at:
# https://github.com/rgl/windows-evaluation-isos-scraper/tree/main/data
set -euo pipefail

windows_names=(
    windows-11
    windows-2022
    windows-2025
)

for name in "${windows_names[@]}"; do
    wget -qO- "https://raw.githubusercontent.com/rgl/windows-evaluation-isos-scraper/main/data/$name.json"
done \
| jq -s 'reduce .[] as $item ({}; .[$item.name] = $item)' \
> windows-evaluation-isos.json
