# dgx-vllm

Automated nightly builds of [eugr/spark-vllm-docker](https://github.com/eugr/spark-vllm-docker) containers.

## Container Variants

| Image                                           | Build Flags | Description         |
|-------------------------------------------------|-------------|---------------------|
| `ghcr.io/spark-arena/dgx-vllm-eugr-nightly`     | _(none)_    | Standard vLLM build |
| `ghcr.io/spark-arena/dgx-vllm-eugr-nightly-tf5` | `-tf5`      | Transformers >=5.0  |

## Tagging Scheme

Each variant receives 3 tags per build:

- **`YYYYMMDDNN`** — Monotonically increasing build identifier (NN = 01, 02, ...)
- **`YYYYMMDD`** — Overwritten to point to the latest build of that day
- **`latest`** — Always the most recent build
