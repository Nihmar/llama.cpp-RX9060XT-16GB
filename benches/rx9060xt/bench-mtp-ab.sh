#!/usr/bin/env bash
# A/B MTP fisso vs adattivo (PR 27210) sugli stessi prompt.
# usage: bench-mtp-ab.sh <build-dir> <label> <model-path> <ctx>
set -euo pipefail

build="${1:?usage: bench-mtp-ab.sh <build-dir> <label> <model-path> <ctx>}"
label="${2:?}"
model="${3:?}"
ctx="${4:?}"

srv="$build/bin/llama-server"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
outdir="$here/results"; mkdir -p "$outdir"
out="$outdir/mtp-ab-${label}-$(date +%Y%m%d-%H%M%S).md"
port=8192

run_config() {
  local name="$1"; shift
  echo "== $name =="
  "$srv" -m "$model" -ngl 99 -fa on -ctk q8_0 -ctv q4_0 -c "$ctx" \
    --device ROCm0 --no-mmproj-offload -t 8 --cache-type-k-draft q4_0 --cache-type-v-draft q4_0 \
    --port "$port" "$@" > "$outdir/mtp-ab-$name.srv.log" 2>&1 &
  local pid=$!
  for i in $(seq 1 300); do
    curl -sf -o /dev/null "http://127.0.0.1:$port/health" && break
    kill -0 $pid 2>/dev/null || { echo "$name: server morto"; return 1; }
    sleep 1
  done
  python3 "$here/mtp-ab-client.py" "$port" "$name" "$out"
  kill $pid 2>/dev/null || true
  wait $pid 2>/dev/null || true
  # attende il rilascio della VRAM (ROCm non la libera subito)
  for i in $(seq 1 60); do
    used=$(cat /sys/class/drm/card1/device/mem_info_vram_used 2>/dev/null || echo 0)
    [ "$used" -lt 2000000000 ] && break
    sleep 1
  done
}

{
  echo "# MTP A/B: $label"
  echo
  echo "- modello: \`$model\`"
  echo "- ctx: $ctx"
  echo
} > "$out"

run_config "n1" --spec-type draft-mtp,ngram-mod --spec-draft-n-max 1 --parallel 1 || echo "n1 fallito"
run_config "n2" --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 --parallel 1 || echo "n2 fallito"
run_config "n3" --spec-type draft-mtp,ngram-mod --spec-draft-n-max 3 --parallel 1 || echo "n3 fallito"

echo
echo "risultati in: $out"
