#!/bin/bash
set -euo pipefail

tag="ansible-$(basename "$PWD")"

# build the ansible image.
DOCKER_BUILDKIT=1 docker build -f Dockerfile.ansible -t "$tag" .

# rewrite paths to be relative to /host.
args=()
for arg in "$@"; do
    arg="${arg/\/tmp\//\/host\/tmp\/}"
    arg="${arg/\/home\//\/host\/home\/}"
    args+=("$arg")
done
#for arg in "${args[@]}"; do echo "ARG: $arg"; done

# execute ansible-playbook.
exec docker run --rm --net=host -v '/:/host' "$tag" ansible-playbook "${args[@]}"
