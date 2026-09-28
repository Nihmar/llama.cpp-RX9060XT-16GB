#!/usr/bin/env bash
# Misura il riuso del prompt tra richieste (TTFT) con varie config di cache.
# usage: bench-cache.sh <build-dir> <label> <math|g12|g4> <test-name> -- <srv args extra>
set -euo pipefail

build="${1:?usage: bench-cache.sh <build-dir> <label> <model> <test-name> -- [args]}"
label="${2:?}"
which="${3:?}"
tname="${4:?}"
shift 4 || true
[[ "${1:-}" == "--" ]] && shift || true

srv="$build/bin/llama-server"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
outdir="$here/results"; mkdir -p "$outdir"
out="$outdir/cache-${label}-${which}-${tname}-$(date +%Y%m%d-%H%M%S).md"

M="${LLAMA_CACHE:-$HOME/mnt/speed/models}"
MATH="$M/models--ISTA-DASLab--Qwen3.8-27B-GSQ-RCO-GGUF/snapshots/d562806dbafae37109975e970aae91b43e73b440/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
G12="$M/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
G4="$M/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf"
declare -A MODELS=( [math]="$MATH" [g12]="$G12" [g4]="$G4" )
declare -A CTK=( [math]="q8_0" [g12]="q8_0" [g4]="q4_0" )
declare -A CTV=( [math]="q4_0" [g12]="q4_0" [g4]="q4_0" )
declare -A NGL=( [math]=99 [g12]=999 [g4]=999 )

port=8198
log="$outdir/cache-${label}-${tname}.srv.log"
prompt_file="$here/prompts/continue-code.txt"

"$srv" -m "${MODELS[$which]}" --port "$port" --host 127.0.0.1 \
  -ngl "${NGL[$which]}" -fa on -ctk "${CTK[$which]}" -ctv "${CTV[$which]}" \
  -t 12 -np 1 -c 32768 "$@" > "$log" 2>&1 &
srv_pid=$!
trap 'kill $srv_pid 2>/dev/null || true' EXIT

for i in $(seq 1 180); do
  if curl -s -o /dev/null "http://127.0.0.1:$port/health"; then break; fi
  if ! kill -0 $srv_pid 2>/dev/null; then echo "server terminato, vedi $log" >&2; exit 1; fi
  sleep 1
done

python3 - "$port" "$prompt_file" "$out" "$label" "$which" "$tname" "$*" <<'PY'
import json, sys, urllib.request, time

port, prompt_file, out, label, which, tname, extra = sys.argv[1:8]
base = open(prompt_file, encoding="utf-8").read()
# ripeti il prompt per arrivare a ~10k caratteri di contesto condiviso
big = (base + "\n\n") * 6
follow = big + "\n\nNow summarize the code above in one paragraph."

def req(prompt, n=8):
    body = {"prompt": prompt, "n_predict": n, "temperature": 0.0, "top_k": 1,
            "cache_prompt": True, "stream": False}
    r = urllib.request.Request(f"http://127.0.0.1:{port}/completion",
                               data=json.dumps(body).encode(),
                               headers={"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(r, timeout=600) as resp:
        d = json.loads(resp.read())
    return time.time() - t0, d.get("timings", {})

rows = []
wall, t = req(big)                      # 1: prompt freddo
rows.append(("cold (primo invio)", wall, t.get("prompt_n"), t.get("prompt_ms")))
wall, t = req(big)                      # 2: stesso prompt
rows.append(("identico (2a volta)", wall, t.get("prompt_n"), t.get("prompt_ms")))
wall, t = req(follow)                   # 3: stesso prefisso + coda nuova
rows.append(("prefisso condiviso + coda", wall, t.get("prompt_n"), t.get("prompt_ms")))

lines = [f"# cache test: {label} / {which} / {tname}", "", f"- extra args: `{extra}`", "",
         "| caso | wall s | prompt_n | prompt_ms |", "|---|---|---|---|"]
for name, wall, pn, pms in rows:
    pms = f"{pms:.0f}" if pms else "-"
    pn = pn if pn is not None else "-"
    lines.append(f"| {name} | {wall:.2f} | {pn} | {pms} |")
open(out, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PY

echo
echo "risultati in: $out (log server: $log)"
