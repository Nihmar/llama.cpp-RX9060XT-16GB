#!/usr/bin/env bash
# Benchmark dei 3 modelli target su un binario specifico (llama-bench).
# usage: bench-models.sh <build-dir> <label> <math|g12|g4|all> [suite] [extra llama-bench args...]
# suites: base (default) | scale | kv | batch | threads | fa
# env: REPS (default 3)
set -euo pipefail

build="${1:?usage: bench-models.sh <build-dir> <label> <math|g12|g4|all> [suite] [extra args]}"
label="${2:?}"
which="${3:?}"
suite="${4:-base}"
shift 4 || true

bench="$build/bin/llama-bench"
[[ -x "$bench" ]] || { echo "non trovato: $bench" >&2; exit 1; }

outdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/results"
mkdir -p "$outdir"
out="$outdir/${label}-${which}-${suite}-$(date +%Y%m%d-%H%M%S).md"

M="${LLAMA_CACHE:-$HOME/mnt/speed/models}"
MATH="$M/models--ISTA-DASLab--Qwen3.8-27B-GSQ-RCO-GGUF/snapshots/d562806dbafae37109975e970aae91b43e73b440/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
G12="$M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
G4="$M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf"

declare -A MODELS=( [math]="$MATH" [g12]="$G12" [g4]="$G4" )
# KV del preset per modello
declare -A CTK=( [math]="q8_0" [g12]="q8_0" [g4]="q4_0" )
declare -A CTV=( [math]="q4_0" [g12]="q4_0" [g4]="q4_0" )
# ngl del preset (99 per math, 999 per gemma)
declare -A NGL=( [math]=99 [g12]=999 [g4]=999 )

if [[ "$which" == "all" ]]; then
  targets=(math g12 g4)
else
  targets=("$which")
fi

{
  echo "# llama-bench: $label / $which / suite=$suite"
  echo
  echo "- data: $(date '+%F %T')"
  echo "- binario: \`$bench\`"
  echo "- suite: \`$suite\`"
  echo
} > "$out"

run() {
  local desc="$1"; shift
  echo "## $desc" >> "$out"
  echo '```' >> "$out"
  "$bench" "$@" -r "${REPS:-3}" -o md >> "$out" 2>&1 || echo "ERRORE (rc=$?)" >> "$out"
  echo '```' >> "$out"
  echo >> "$out"
  echo "-- $desc" >&2
}

for t in "${targets[@]}"; do
  m="${MODELS[$t]}"
  ctk="${CTK[$t]}"; ctv="${CTV[$t]}"; ngl="${NGL[$t]}"
  case "$suite" in
    base)
      run "$t base (-p 512,2048,8192 -n 128 -fa on -ctk $ctk -ctv $ctv -ngl $ngl -t 12)" \
        -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 -p 512,2048,8192 -n 128 "$@"
      ;;
    scale)
      # prefill a dimensioni crescenti + decode a profondita' diverse (KV caldo)
      case "$t" in
        math|g12)
          run "$t scale (-p 512,8192,32768,65536 -d 8192,32768 -n 128)" \
            -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 \
            -p 512,8192,32768,65536 -n 128 -d 8192,32768 "$@"
          ;;
        g4)
          run "$t scale (-p 512,8192,16384 -d 8192 -n 128)" \
            -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 \
            -p 512,8192,16384 -n 128 -d 8192 "$@"
          ;;
      esac
      ;;
    kv)
      run "$t kv: ctk=${ctk} ctv=${ctv} (preset)" \
        -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 -p 2048,8192 -n 128 "$@"
      run "$t kv: ctk=q4_0 ctv=q4_0" \
        -m "$m" -ngl "$ngl" -fa on -ctk q4_0 -ctv q4_0 -t 12 -p 2048,8192 -n 128 "$@"
      run "$t kv: ctk=q8_0 ctv=q8_0" \
        -m "$m" -ngl "$ngl" -fa on -ctk q8_0 -ctv q8_0 -t 12 -p 2048,8192 -n 128 "$@"
      ;;
    batch)
      for bub in 512:512 2048:512 4096:512 8192:512 4096:1024; do
        b="${bub%%:*}"; ub="${bub##*:}"
        run "$t batch b=$b ub=$ub (-ctk $ctk -ctv $ctv)" \
          -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 -b "$b" -ub "$ub" -p 2048,8192 -n 128 "$@"
      done
      ;;
    threads)
      for th in 8 12 16; do
        run "$t threads=$th (kv $ctk/$ctv)" \
          -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t "$th" -p 2048,8192 -n 128 "$@"
      done
      ;;
    fa)
      run "$t fa=on" -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 -p 2048,8192 -n 128 "$@"
      run "$t fa=off" -m "$m" -ngl "$ngl" -fa off -ctk f16 -ctv f16 -t 12 -p 2048,8192 -n 128 "$@"
      ;;
    nkvo)
      # KV in system RAM (costo del "muro PCIe", baseline del KV streaming)
      run "$t nkvo=1 kv in RAM (d 8192,32768)" \
        -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 -nkvo 1 \
        -p 512,8192 -n 128 -d 8192,32768 "$@"
      run "$t nkvo=0 riferimento" \
        -m "$m" -ngl "$ngl" -fa on -ctk "$ctk" -ctv "$ctv" -t 12 -nkvo 0 \
        -p 512,8192 -n 128 -d 8192,32768 "$@"
      ;;
    *)
      echo "suite sconosciuta: $suite" >&2; exit 1;;
  esac
done

echo "risultati in: $out"
