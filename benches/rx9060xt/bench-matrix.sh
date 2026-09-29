#!/usr/bin/env bash
# Matrice: per ogni modello, miglior config Vulkan e miglior config ROCm,
# prefill a 3 profondita', decode su 3 tipi di testo (codice/ripetitivo/prosa)
# con spec on/off, e VRAM per caso.
# usage: bench-matrix.sh <build-dir> [solo-config]
set -euo pipefail
build="${1:?usage: bench-matrix.sh <build-dir> [config]}"
only="${2:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="$build/bin/llama-bench"
srv="$build/bin/llama-server"
out="$here/results/matrix-$(date +%Y%m%d-%H%M%S).md"
port=8192

M=/home/alessandro/mnt/speed/models
MATH="$M/models--ISTA-DASLab--Qwen3.8-27B-GSQ-RCO-GGUF/snapshots/d562806dbafae37109975e970aae91b43e73b440/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
G12="$M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
MTP12="$M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/mtp-gemma-4-12B-it.gguf"
G4="$M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf"
MTP4="$M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/mtp-gemma-4-E4B-it.gguf"

wait_vram() {
  for i in $(seq 1 90); do
    used=$(cat /sys/class/drm/card1/device/mem_info_vram_used 2>/dev/null || echo 0)
    [ "$used" -lt 2000000000 ] && return 0
    sleep 1
  done
}

config() {   # key model device ctx ctk ctv nmax md depth-list
  local key="$1" model="$2" dev="$3" ctx="$4" ctk="$5" ctv="$6" nmax="$7" mdf="$8" depths="$9"
  [ -n "$only" ] && [ "$only" != "$key" ] && return 0
  echo "########## $key ##########" >&2
  { echo "## $key"; echo; echo "- modello: \`$(basename "$model")\`"; echo "- device: $dev, ctx: $ctx, KV: $ctk/$ctv, MTP n-max: $nmax"; echo; } >> "$out"

  # 1) prefill a profondita' diverse
  echo "== prefill $key ==" >&2
  { echo "### prefill (t/s)"; echo '```'
    local extra=(); [ -n "$mdf" ] && extra=(-md "$mdf")
    "$bin" -m "$model" -ngl 99 -fa on -ctk "$ctk" -ctv "$ctv" -t 8 --device "$dev" \
      -b 2048 -ub 512 -p 8192 -n 0 -d "$depths" -r 2 -o md
    echo '```'; } >> "$out"

  # 2) decode: spec off poi spec on, su 3 tipi di testo
  for mode in off on; do
    local args=(-m "$model" -ngl 99 -fa on -ctk "$ctk" -ctv "$ctv" -c "$ctx" -t 8 -np 1
                -b 2048 -ub 512 --device "$dev" --no-mmproj-offload --port "$port")
    [ -n "$mdf" ] && args+=(-md "$mdf")
    if [ "$mode" = on ]; then
      args+=(--spec-type draft-mtp,ngram-mod --spec-draft-n-max "$nmax" --spec-draft-p-min 0.1
             --cache-type-k-draft q4_0 --cache-type-v-draft q4_0
             --spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64)
    fi
    echo "== decode $key (spec $mode) ==" >&2
    "$srv" "${args[@]}" > "$here/results/matrix-$key-$mode.srv.log" 2>&1 &
    local pid=$!
    for i in $(seq 1 300); do curl -sf -o /dev/null "http://127.0.0.1:$port/health" && break; sleep 1; done
    python3 "$here/matrix-client.py" "$port" "$key spec=$mode" "$out" 192
    kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true; wait_vram
  done
}

: > "$out"
{ echo "# Matrice backend x modello x profondita' x tipo di testo"; echo
  echo "- binario: \`$build\`"; echo "- data: $(date '+%F %T')"; echo; } >> "$out"

config math-rocm  "$MATH" ROCm0   98304  q8_0 q4_0 2 ""        "0,8192,32768"
config math-vk    "$MATH" Vulkan0 131072 q8_0 q4_0 2 ""        "0,8192,32768"
config g12-rocm   "$G12"  ROCm0   160000 q8_0 q4_0 3 "$MTP12"  "0,8192,32768"
config g12-vk     "$G12"  Vulkan0 160000 q8_0 q4_0 3 "$MTP12"  "0,8192,32768"
config g4-rocm    "$G4"   ROCm0   16384  q4_0 q4_0 2 "$MTP4"   "0,8192"
config g4-vk      "$G4"   Vulkan0 16384  q4_0 q4_0 2 "$MTP4"   "0,8192"

echo "risultati in: $out"
