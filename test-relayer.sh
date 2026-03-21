#!/bin/bash
set -euo pipefail

# Local test script that mimics the GitHub Actions build workflow
# for Dockerfile.relayer, without freeing disk space, pushing, or
# updating state files.
#
# Usage:
#   ./test-relayer.sh                  # default: nightly variant, no extra flags
#   ./test-relayer.sh --tf5            # nightly-tf5 variant
#   ./test-relayer.sh --skip-build     # skip vllm-node build, reuse existing image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPARK_VLLM_DIR="/tmp/spark-vllm-docker"
SOURCE_IMAGE="vllm-node"
BUILD_FLAGS=""
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tf5)
            BUILD_FLAGS="--tf5"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo "Unknown flag: $1"
            echo "Usage: $0 [--tf5] [--skip-build]"
            exit 1
            ;;
    esac
done

# ── Step 1: Clone upstream (if needed) and build vllm-node ──
if [ "$SKIP_BUILD" = true ]; then
    echo "==> Skipping vllm-node build (--skip-build)"
    if ! docker image inspect "$SOURCE_IMAGE" &>/dev/null; then
        echo "ERROR: Image '$SOURCE_IMAGE' not found. Run without --skip-build first."
        exit 1
    fi
else
    if [ -d "$SPARK_VLLM_DIR" ]; then
        echo "==> Updating existing spark-vllm-docker clone..."
        git -C "$SPARK_VLLM_DIR" pull --ff-only || {
            echo "==> Pull failed, re-cloning..."
            rm -rf "$SPARK_VLLM_DIR"
            git clone --depth 1 https://github.com/eugr/spark-vllm-docker.git "$SPARK_VLLM_DIR"
        }
    else
        echo "==> Cloning spark-vllm-docker..."
        git clone --depth 1 https://github.com/eugr/spark-vllm-docker.git "$SPARK_VLLM_DIR"
    fi

    echo "==> Building vllm-node image..."
    cd "$SPARK_VLLM_DIR"
    bash build-and-copy.sh --tag "$SOURCE_IMAGE" $BUILD_FLAGS
    cd "$SCRIPT_DIR"
fi

# ── Step 2: Detect upstream base image ──
echo "==> Detecting upstream base image..."
BASE_IMAGE=$(grep -m1 '^FROM ' "$SPARK_VLLM_DIR/Dockerfile" | awk '{print $2}')
echo "    Base image: ${BASE_IMAGE}"

# ── Step 3: Build re-layered image ──
TAG="local-test"
VARIANT="nightly"
[ -n "$BUILD_FLAGS" ] && VARIANT="nightly-tf5"
OUTPUT_IMAGE="dgx-vllm-test-${VARIANT}:${TAG}"

echo "==> Building re-layered image: ${OUTPUT_IMAGE}"
docker build -f "$SCRIPT_DIR/Dockerfile.relayer" \
    --build-arg SOURCE_IMAGE="$SOURCE_IMAGE" \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    -t "$OUTPUT_IMAGE" \
    "$SCRIPT_DIR"

# ── Step 4: Quick sanity checks ──
echo ""
echo "==> Build succeeded: ${OUTPUT_IMAGE}"
echo ""
echo "--- Image size ---"
docker image inspect "$OUTPUT_IMAGE" --format '{{.Size}}' | numfmt --to=iec-i --suffix=B
echo ""
echo "--- Layer count ---"
docker history "$OUTPUT_IMAGE" --no-trunc -q | wc -l
echo ""
echo "--- Checking /workspace contents ---"
docker run --rm "$OUTPUT_IMAGE" find /workspace -maxdepth 2 -type d | head -30
echo ""
echo "--- Checking vllm importable ---"
docker run --rm "$OUTPUT_IMAGE" python -c "import vllm; print(f'vllm {vllm.__version__}')"
echo ""
echo "Done. To inspect further:"
echo "  docker run --rm -it ${OUTPUT_IMAGE} bash"