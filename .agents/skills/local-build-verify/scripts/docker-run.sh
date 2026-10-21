#!/usr/bin/env bash
# Run commands against a clean copy of the repo in a linux/amd64 Ubuntu container.
# Usage: docker-run.sh '<commands>'   (run from the repo root)
# Set WORK_DIR=<host dir> to keep /work (and its temp/ cache) between runs.
set -euo pipefail

if [ $# -ne 1 ]; then
	echo "usage: $0 '<commands>'" >&2
	exit 1
fi

work_mount=()
if [ -n "${WORK_DIR:-}" ]; then
	mkdir -p "$WORK_DIR"
	work_mount=(-v "$(cd "$WORK_DIR" && pwd)":/work)
fi

docker run --rm --platform linux/amd64 \
	-v "$PWD":/repo:ro ${work_mount[@]+"${work_mount[@]}"} \
	-e GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)" \
	ubuntu bash -c '
		set -e
		apt-get -qq update
		apt-get -qq install -y jq curl unzip zip rsync openjdk-21-jre-headless >/dev/null
		rsync -a --exclude build --exclude temp --exclude .git /repo/ /work/
		cd /work && mkdir -p temp
		'"$1"
