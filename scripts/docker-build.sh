#!/bin/sh
# Build the PocketTerm35 postmarketOS image inside a Linux ARM64 Docker container.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_TAG="pocketterm35-pmos-builder"
HOME_VOLUME="pocketterm35-pmos-home"
TTY_ARGS="-i"

if [ -t 0 ]; then
    TTY_ARGS="-it"
fi

cd "$PROJECT_DIR"

docker build --platform linux/arm64 -t "$IMAGE_TAG" .

docker run --rm $TTY_ARGS \
    --platform linux/arm64 \
    --privileged \
    -e PMB_FILE_WAIT_UNTIL_EXISTS_MAX=1200 \
    -v "$PROJECT_DIR:/work" \
    -v "$HOME_VOLUME:/home/builder" \
    -w /work \
    "$IMAGE_TAG" "$@"
