#!/usr/bin/env bash
# A/B dei knob Vulkan sui gemma (suite base, llama-bench).
# usage: bench-vk-knobs.sh <build-dir> <model-path> <label>
set -euo pipefail
build="${1:?usage: bench-vk-knobs.sh <build-dir> <model> <label>}"
model="${2:?}"
label="${3:?}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$here/results/vk-knobs-${label}-$(date +%Y%m%d-%H%M%S).md"
bench="$build/bin/llama-bench"
run() {
  local name="$1"; shift
  echo "== $name ==" >&2
  { echo "## $name"; echo '```'; "$bench" -m "$model" -ngl 999 -fa on -ctk q8_0 -ctv q4_0 -t 12 \
      -p 512,8192,32768 -n 128 -d 8192 -r 2 -o md "$@"; echo '```'; } >> "$out"
}
: > "$out"
run "default"
GGML_VK_ALLOW_GRAPHICS_QUEUE=1 run "allow-graphics-queue"
GGML_VK_DISABLE_ASYNC=1 run "disable-async"
GGML_VK_DISABLE_COOPMAT=1 run "disable-coopmat"
echo "risultati in: $out"
