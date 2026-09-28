#!/usr/bin/env bash
# Confronto configurazioni di speculative decoding via bench-spec.sh.
# usage: run-spec-tests.sh <build-dir> <label> [math|g12|g4|all]
set -euo pipefail

root=/home/alessandro/Projects/llama.cpp-RX9060XT-16GB
cd "$root"
export ROCM_PATH=/opt/rocm
export LD_LIBRARY_PATH="$ROCM_PATH/lib:${LD_LIBRARY_PATH:-}"

build="${1:?usage: run-spec-tests.sh <build-dir> <label> [math|g12|g4|all]}"
label="${2:?}"
sel="${3:-all}"

M="${LLAMA_CACHE:-$HOME/mnt/speed/models}"
MTP12="$M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/mtp-gemma-4-12B-it.gguf"
MTP4="$M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/mtp-gemma-4-E4B-it.gguf"
DFLSH="$M/models--williamliao--gemma-4-12B-it-DFlash-GGUF/snapshots/05cc859a6ef67e83e415a6094b9e0b26ec7d8156/gemma-4-12B-it-DFlash-Q4_K_M.gguf"

spec() { ./benches/rx9060xt/bench-spec.sh "$build" "$label" "$1" "$2" -- "${@:3}"; }

if [[ "$sel" == "all" || "$sel" == "math" ]]; then
  spec math none-none       --spec-type none
  spec math mtp-n2          --spec-type draft-mtp --spec-draft-n-max 2
  spec math mtp-n4          --spec-type draft-mtp --spec-draft-n-max 4
  spec math mtp+nmod        --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2
fi

if [[ "$sel" == "all" || "$sel" == "g12" ]]; then
  spec g12 none-none        --spec-type none
  spec g12 mtp-n2           --spec-type draft-mtp --spec-draft-n-max 2 -md "$MTP12"
  spec g12 mtp-n4           --spec-type draft-mtp --spec-draft-n-max 4 -md "$MTP12"
  spec g12 dflash-15        --spec-type draft-dflash --spec-draft-n-max 15 -md "$DFLSH"
  spec g12 nmod-tuned       --spec-type ngram-mod --spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64
  spec g12 mtp+nmod         --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 -md "$MTP12" \
                            --spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64
fi

if [[ "$sel" == "all" || "$sel" == "g4" ]]; then
  spec g4 none-none         --spec-type none
  spec g4 mtp-n2            --spec-type draft-mtp --spec-draft-n-max 2 -md "$MTP4"
  spec g4 mtp+nmod          --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 -md "$MTP4"
fi

echo
echo "test spec completati - risultati in benches/rx9060xt/results/spec-*.md"
