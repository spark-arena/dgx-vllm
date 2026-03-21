# dgx-vllm

Automated nightly builds of [eugr/spark-vllm-docker](https://github.com/eugr/spark-vllm-docker) containers, re-layered
for GHCR compatibility (10GB layer limit) and pushed to `ghcr.io/spark-arena/`.

## Container Variants

| Image                                        | Build Flags          | Description               |
|----------------------------------------------|----------------------|---------------------------|
| `ghcr.io/spark-arena/dgx-vllm-nightly`       | _(none)_             | Standard vLLM build       |
| `ghcr.io/spark-arena/dgx-vllm-nightly-tf5`   | `--pre-transformers` | Transformers >=5.0        |
| `ghcr.io/spark-arena/dgx-vllm-nightly-mxfp4` | `--exp-mxfp4`        | Native MXFP4 quantization |

## Tagging Scheme

Each variant receives 3 tags per build:

- **`YYYYMMDDNN`** — Monotonically increasing build identifier (NN = 01, 02, ...)
- **`YYYYMMDD`** — Overwritten to point to the latest build of that day
- **`latest`** — Always the most recent build

## How It Works

1. **Cron polling** (every hour) checks upstream `eugr/spark-vllm-docker` for new commits, releases, or tags
2. If changes are detected, builds all variants **sequentially** (to manage runner disk space)
3. Each build clones upstream, runs `build-and-copy.sh`, then re-layers the image to fit within GHCR limits
4. Tags and pushes to GHCR, then updates `upstream-state.json` and `sequence.txt`

## Manual Trigger

Go to **Actions > Build and Push DGX vLLM Containers > Run workflow** to force a build regardless of upstream changes.

## Usage

```bash
docker pull ghcr.io/spark-arena/dgx-vllm-nightly:latest
```
