#!/usr/bin/env python3
"""Client per bench-mtp-ab.sh: 3 prompt (codice, ragionamento, codice ripetuto)."""
import json
import sys
import urllib.request

port, name, out = sys.argv[1], sys.argv[2], sys.argv[3]

code = open("/home/alessandro/Projects/llama.cpp-RX9060XT-16GB/benches/rx9060xt/prompts/continue-code.txt",
            encoding="utf-8").read()
reason = ("Spiega in modo dettagliato perche' il cielo e' blu, partendo dalla diffusione di Rayleigh "
          "e arrivando alla percezione umana. Scrivi un saggio di tre paragrafi.")


def run(prompt, n=192):
    body = {"prompt": prompt, "n_predict": n, "temperature": 0.0, "top_k": 1,
            "cache_prompt": False, "stream": False}
    req = urllib.request.Request(f"http://127.0.0.1:{port}/completion",
                                 data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as resp:
        return json.loads(resp.read()).get("timings", {})


rows = []
run(code, 32)  # warmup
for prompt_name, prompt in (("codice", code), ("ragionamento", reason), ("codice-bis", code)):
    t = run(prompt)
    rows.append((prompt_name, t))

lines = [f"## {name}", "", "| prompt | pred t/s | prompt t/s | draft | accepted | acc |",
         "|---|---|---|---|---|---|"]
for pname, t in rows:
    dn, da = t.get("draft_n"), t.get("draft_n_accepted")
    acc = f"{da/dn*100:.1f}%" if dn else "-"
    lines.append(f"| {pname} | {t.get('predicted_per_second', 0):.1f} | "
                 f"{t.get('prompt_per_second', 0):.1f} | {dn} | {da} | {acc} |")
text = "\n".join(lines) + "\n"
with open(out, "a", encoding="utf-8") as fh:
    fh.write(text + "\n")
print(text)
