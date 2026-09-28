#!/usr/bin/env bash
# Misura lo speculative decoding via llama-server (/completion):
# throughput prompt/decodifica, draft_n, draft_n_accepted.
# usage: bench-spec.sh <build-dir> <label> <math|g12|g4> <nome-test> -- <srv args extra...>
# esempio:
#   bench-spec.sh build-hip hip g12 mtp-off -- --spec-type none
#   bench-spec.sh build-hip hip g12 mtp+nmod -- --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 --draft-p-min 0.1
set -euo pipefail

build="${1:?usage: bench-spec.sh <build-dir> <label> <math|g12|g4> <test-name> -- [args]}"
label="${2:?}"
which="${3:?}"
tname="${4:?}"
shift 4 || true
[[ "${1:-}" == "--" ]] && shift || true

srv="$build/bin/llama-server"
[[ -x "$srv" ]] || { echo "non trovato: $srv" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
outdir="$here/results"; mkdir -p "$outdir"
out="$outdir/spec-${label}-${which}-${tname}-$(date +%Y%m%d-%H%M%S).md"

M="${LLAMA_CACHE:-$HOME/mnt/speed/models}"
MATH="$M/models--ISTA-DASLab--Qwen3.8-27B-GSQ-RCO-GGUF/snapshots/d562806dbafae37109975e970aae91b43e73b440/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
G12="$M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
G4="$M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf"

declare -A MODELS=( [math]="$MATH" [g12]="$G12" [g4]="$G4" )
declare -A CTK=( [math]="q8_0" [g12]="q8_0" [g4]="q4_0" )
declare -A CTV=( [math]="q4_0" [g12]="q4_0" [g4]="q4_0" )
declare -A NGL=( [math]=99 [g12]=999 [g4]=999 )

# draft model per lo spec decoding (passare con: -- -md <path>)
# - math: MTP integrato nel modello principale (nessun file)
# - g12:   $M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/mtp-gemma-4-12B-it.gguf
# - g4:    $M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/mtp-gemma-4-E4B-it.gguf
# - g12 dflash: $M/models--williamliao--gemma-4-12B-it-DFlash-GGUF/snapshots/05cc859a6ef67e83e415a6094b9e0b26ec7d8156/gemma-4-12B-it-DFlash-Q4_K_M.gguf

model="${MODELS[$which]}"
prompt_file="$here/prompts/continue-code.txt"
[[ -f "$prompt_file" ]] || { echo "manca $prompt_file" >&2; exit 1; }

port=8199
log="$outdir/spec-${label}-${tname}.srv.log"

# usa la GPU di default del backend scelto (ROCm0/Vulkan0 automatico col rispettivo build)
"$srv" -m "$model" --port "$port" --host 127.0.0.1 \
  -ngl "${NGL[$which]}" -fa on -ctk "${CTK[$which]}" -ctv "${CTV[$which]}" \
  -t 12 -np 1 --no-cache-prompt -c 32768 "$@" > "$log" 2>&1 &
srv_pid=$!
trap 'kill $srv_pid 2>/dev/null || true' EXIT

for i in $(seq 1 120); do
  if curl -s -o /dev/null "http://127.0.0.1:$port/health"; then break; fi
  if ! kill -0 $srv_pid 2>/dev/null; then echo "server terminato, vedi $log" >&2; exit 1; fi
  sleep 1
done

python3 - "$port" "$prompt_file" "$out" "$label" "$which" "$tname" "$*" <<'PY'
import json, sys, urllib.request, time

port, prompt_file, out, label, which, tname, extra = sys.argv[1:8]
prompt = open(prompt_file, encoding="utf-8").read()

def req(body):
    r = urllib.request.Request(f"http://127.0.0.1:{port}/completion",
                               data=json.dumps(body).encode(),
                               headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=600) as resp:
        return json.loads(resp.read())

results = []
for run in range(3):
    t0 = time.time()
    res = req({"prompt": prompt, "n_predict": 192, "temperature": 0.0,
               "top_k": 1, "cache_prompt": False, "stream": False})
    wall = time.time() - t0
    t = res.get("timings", {})
    results.append((run, wall, t.get("prompt_per_second"), t.get("predicted_per_second"),
                    t.get("draft_n"), t.get("draft_n_accepted")))

ok = [r for r in results if r[4] is not None]
# scarta la prima run (warmup)
meas = [r for r in results[1:] if r[4] is not None]
lines = []
lines.append(f"# spec test: {label} / {which} / {tname}\n")
lines.append(f"- extra args: `{extra}`\n")
lines.append("| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |")
lines.append("|---|---|---|---|---|---|---|")
for run, wall, pp, tg, dn, da in results:
    rate = f"{(da/dn*100):.1f}%" if dn else "n/a"
    pp = f"{pp:.1f}" if pp else "-"
    tg = f"{tg:.1f}" if tg else "-"
    lines.append(f"| {run} | {wall:.1f} | {pp} | {tg} | {dn} | {da} | {rate} |")
if meas:
    import statistics as st
    tg = st.mean(r[3] for r in meas if r[3])
    dn = sum(r[4] for r in meas if r[4])
    da = sum(r[5] for r in meas if r[5])
    lines.append(f"\n**media (run 1-2, esclusa warmup)**: pred {tg:.1f} t/s, accept {da}/{dn} = {da/dn*100:.1f}%")
open(out, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PY

echo
echo "risultati in: $out (log server: $log)"
