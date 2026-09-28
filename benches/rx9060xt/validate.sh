#!/usr/bin/env bash
# Validazione end-to-end del router con i preset correnti.
# usage: validate.sh [porta]
set -uo pipefail

PORT="${1:-8181}"
PRESET="${HOME}/.config/llama.cpp/preset.ini"
LOG=/tmp/llama-router-validation.log

pkill -x llama 2>/dev/null || true
pkill -x llama-server 2>/dev/null || true
sleep 2

LD_LIBRARY_PATH=/opt/rocm/lib nohup llama serve --models-preset "$PRESET" --models-max 2 \
  --tools all --port "$PORT" --host 127.0.0.1 > "$LOG" 2>&1 &
rpid=$!
echo "router pid=$rpid, log=$LOG"

for i in $(seq 1 180); do
  curl -sf -o /dev/null "http://127.0.0.1:$PORT/health" && break
  kill -0 $rpid 2>/dev/null || { echo "router morto"; tail -20 "$LOG"; exit 1; }
  sleep 1
done
echo "router pronto"

ask() {
  local model="$1"
  echo
  echo "=== $model ==="
  local t0=$(date +%s) out rc
  out=$(curl -sf --max-time 900 "http://127.0.0.1:$PORT/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Rispondi solo: OK\"}],\"max_tokens\":16,\"temperature\":0}" 2>&1)
  rc=$?
  echo "rc=$rc in $(( $(date +%s) - t0 ))s: $(echo "$out" | head -c 200)"
  echo "VRAM: $(cat /sys/class/drm/card1/device/mem_info_vram_used) byte"
  pgrep -ax llama | grep -v "^$rpid " | sed 's/--reasoning-budget-message.*//;s/--chat-template-kwargs.*--host//' | cut -c1-190
}

for m in "$@"; do :; done
# modelli di default
ask "${VALIDATE_MODELS_0:-math-38-27b}"
ask "${VALIDATE_MODELS_1:-math-38-27b-long}"
ask "${VALIDATE_MODELS_2:-gemma-4-12b}"
ask "${VALIDATE_MODELS_3:-gemma-4-e4b}"

echo
echo "=== log: device/acceptance ==="
grep -E "device|draft acceptance" "$LOG" | tail -12
