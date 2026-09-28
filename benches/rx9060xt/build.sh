#!/usr/bin/env bash
# Build llama.cpp per RX 9060 XT 16GB (gfx1200).
# usage: build.sh hip|vulkan|both [extra cmake args...]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
backend="${1:-hip}"
shift || true

export ROCM_PATH="${ROCM_PATH:-/opt/rocm}"

common=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER_LAUNCHER=ccache
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
)

# combo KV di interesse per i preset: ctk=q8_0 ctv=q4_0 (math, gemma-12b), q4_0/q4_0 (e4b)
fa_quants="f16-f16;q4_0-q4_0;q8_0-q8_0;bf16-bf16;q8_0-q4_0"

case "$backend" in
  hip)
    dir="$root/build-hip"
    extra=(
      -DGGML_HIP=ON
      -DGPU_TARGETS=gfx1200
      -DCMAKE_HIP_COMPILER="$ROCM_PATH/lib/llvm/bin/clang"
      -DCMAKE_HIP_COMPILER_LAUNCHER=ccache
    )
    ;;
  vulkan)
    dir="$root/build-vulkan"
    extra=(-DGGML_VULKAN=ON)
    ;;
  both)
    dir="$root/build-both"
    extra=(
      -DGGML_HIP=ON
      -DGPU_TARGETS=gfx1200
      -DCMAKE_HIP_COMPILER="$ROCM_PATH/lib/llvm/bin/clang"
      -DCMAKE_HIP_COMPILER_LAUNCHER=ccache
      -DGGML_VULKAN=ON
    )
    ;;
  *)
    echo "usage: $0 hip|vulkan|both [extra cmake args...]" >&2
    exit 1
    ;;
esac

# solo per il percorso HIP: aggiungi le combo FA usate dai preset
if [[ "$backend" != "vulkan" ]]; then
  extra+=("-DGGML_CUDA_FA_QUANTS=$fa_quants")
fi

cmake -S "$root" -B "$dir" "${common[@]}" "${extra[@]}" "$@"
cmake --build "$dir" -j "${JOBS:-10}"
echo
echo "OK: binari in $dir/bin"
