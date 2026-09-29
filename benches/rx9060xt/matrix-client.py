#!/usr/bin/env python3
"""Client per la matrice: 3 tipi di testo (codice, ripetitivo, prosa) + VRAM."""
import json
import sys
import urllib.request

port, tag, out, n_pred = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4] or "192")
base = "/home/alessandro/Projects/llama.cpp-RX9060XT-16GB/benches/rx9060xt/prompts"
prompts = [("codice", f"{base}/continue-code.txt"),
           ("ripetitivo", f"{base}/repetitive.txt"),
           ("prosa", f"{base}/prose.txt")]


def vram():
    try:
        return int(open("/sys/class/drm/card1/device/mem_info_vram_used").read().strip())
    except Exception:
        return -1


def run(prompt, n):
    body = {"prompt": prompt, "n_predict": n, "temperature": 0.0, "top_k": 1,
            "cache_prompt": False, "stream": False}
    req = urllib.request.Request(f"http://127.0.0.1:{port}/completion",
                                 data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=1800) as resp:
        return json.loads(resp.read()).get("timings", {})


lines = [f"### {tag}", "", f"VRAM a modello caricato: {vram()/2**30:.2f} GiB", "",
         "| testo | pred t/s | prompt t/s | draft | acc | accept | VRAM dopo |",
         "|---|---:|---:|---:|---:|---:|---:|"]
run(open(prompts[0][1], encoding="utf-8").read(), 32)  # warmup
for name, path in prompts:
    t = run(open(path, encoding="utf-8").read(), n_pred)
    dn, da = t.get("draft_n"), t.get("draft_n_accepted")
    acc = f"{da/dn*100:.1f}%" if dn else "-"
    lines.append(f"| {name} | {t.get('predicted_per_second', 0):.1f} | "
                 f"{t.get('prompt_per_second', 0):.1f} | {dn} | {da} | {acc} | "
                 f"{vram()/2**30:.2f} GiB |")
with open(out, "a", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n\n")
print("\n".join(lines))
