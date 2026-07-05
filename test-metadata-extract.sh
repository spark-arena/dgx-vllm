#!/usr/bin/env bash
# Test script to validate build-metadata.yaml extraction logic locally.
# Uses an already-pulled image — no full build required.
set -euo pipefail

IMAGE="${1:-ghcr.io/spark-arena/dgx-vllm-eugr-nightly:latest}"

echo "=== Extracting /workspace/build-metadata.yaml from: $IMAGE ==="
RAW=$(docker run --rm "$IMAGE" cat /workspace/build-metadata.yaml 2>/dev/null || echo "")

if [ -z "$RAW" ]; then
  echo "ERROR: No build-metadata.yaml found in image"
  exit 1
fi

echo ""
echo "--- Raw YAML contents ---"
echo "$RAW"
echo ""

# ── OLD (broken) extraction logic ──────────────────────────────────────
echo "=== OLD extraction (broken — from build.yml before fix) ==="
OLD_REPO=$(echo "$RAW" | grep -E '^\s*commit:' | head -1 | sed "s/.*build_build_script_commit:\s*['\"]*//" | sed "s/['\"].*//" || echo "")
OLD_VLLM=$(echo "$RAW" | grep -E '^\s*vllm_hash:' | head -1 | sed "s/.*build_vllm_commit:\s*['\"]*//" | sed "s/['\"].*//" || echo "")
OLD_FLASH=$(echo "$RAW" | grep -E '^\s*flashinfer_hash:' | head -1 | sed "s/.*build_flashinfer_commit:\s*['\"]*//" | sed "s/['\"].*//" || echo "")
echo "  repo_commit:     '${OLD_REPO}'"
echo "  vllm_hash:       '${OLD_VLLM}'"
echo "  flashinfer_hash: '${OLD_FLASH}'"
echo ""

# ── NEW (fixed) extraction logic ───────────────────────────────────────
echo "=== NEW extraction (fixed) ==="
NEW_REPO=$(echo "$RAW" | grep -E '^\s*build_script_commit:' | head -1 | sed 's/^[^:]*:\s*//' | tr -d "\"' ")
NEW_VLLM=$(echo "$RAW" | grep -E '^\s*vllm_commit:' | head -1 | sed 's/^[^:]*:\s*//' | tr -d "\"' ")
NEW_FLASH=$(echo "$RAW" | grep -E '^\s*flashinfer_commit:' | head -1 | sed 's/^[^:]*:\s*//' | tr -d "\"' ")
echo "  repo_commit:     '${NEW_REPO}'"
echo "  vllm_hash:       '${NEW_VLLM}'"
echo "  flashinfer_hash: '${NEW_FLASH}'"
echo ""

# ── Validation ─────────────────────────────────────────────────────────
PASS=true
for var_name in NEW_REPO NEW_VLLM NEW_FLASH; do
  val="${!var_name}"
  if [ -z "$val" ]; then
    echo "FAIL: $var_name is empty"
    PASS=false
  fi
done

if $PASS; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
