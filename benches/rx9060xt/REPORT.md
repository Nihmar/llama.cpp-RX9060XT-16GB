# Report finale: master vs ours (RX 9060 XT 16 GB, gfx1200)

> Nota importante: **il codice e' upstream in entrambi i casi**. Dopo i test, nessuna
> delle patch di codice e' stata adottata (tutte sotto soglia o non applicabili, vedi
> "Esperimenti scartati"). La differenza "ours" sta in: scelta del backend per modello,
> flag di build, e preset (contesto, KV, np, spec, mmproj). Il confronto quindi e'
> **setup di partenza (binario Vulkan + preset originali)** vs **setup attuale**.

Dati grezzi: `benches/rx9060xt/results/*.md` (43 file). Riepilogo cumulativo: `RESULTS.md`.
Preset finale: `preset.final.ini` (copia di `~/.config/llama.cpp/preset.ini`).

## Configurazione: `math-38-27b` (Qwen3.8-27B, ibrido SSM)

Prima girava su **Vulkan** (l'unico backend del binario precedente), 128k, **MTP spento**.
Ora: **ROCm0**, IQ3_S 96k (o IQ3_XXS 128k), `np=1`, **MTP+ngram n-max 2**.

### Prefill, t/s (llama-bench, senza spec)

| test | master (Vulkan) | ours (ROCm) | delta |
|---|---:|---:|---:|
| pp512 @ d8192 | 473.5 | 490.7 | +4% |
| pp8192 @ d8192 | 501.1 | 545.0 | +9% |
| pp32768 @ d8192 | 414.5 | 489.9 | +18% |
| pp65536 @ d8192 | 334.9 | 430.8 | +29% |
| pp8192 @ d32768 | 352.5 | 443.2 | +26% |
| pp32768 @ d32768 | 303.7 | 406.1 | +34% |
| pp65536 @ d32768 | 188.4 | 364.8 | **+94%** |

Curva prefill vs profondita' (ours, ROCm, pp8192): 521 t/s a vuoto -> 484 (8k) ->
401 (32k) -> 327 (65k) -> **277 (98k)**. (Il "700 t/s" ricordato era a contesto vuoto
con prompt corto; il calo a ~250-280 a 100k e' confermato.)

### Decode, t/s (prompt di continuazione codice, greedy)

| scenario | master | ours |
|---|---:|---:|
| senza spec | 19.6 | (non piu' usato) |
| codice, prima generazione | - | **67.6-68.0** (110k) / **78.3** (96k) |
| ragionamento libero | - | 32.6 |
| stesso codice rigenerato | - | **164.8-166.9** |

### Contesto e memoria

| | master | ours |
|---|---|---|
| contesto | 128k (senza MTP) | 96k IQ3_S **con MTP** / 128k IQ3_XXS |
| np | 4 (default) | 1 (rs cache 1.88 GB -> 0.47 GB) |
| spec | spento | draft-mtp,ngram-mod, n-max 2 |
| mmproj | CPU (gia') | CPU |

## Configurazione: `gemma-4-12b`

Backend **Vulkan** in entrambi i casi (verificato +10% sul prefill profondo vs ROCm).

### Prefill, t/s (Vulkan, senza spec) - invariato, nessuna patch adottata

| test | master | ours |
|---|---:|---:|
| pp8192 @ d8192 | 966.2 | 966.2 |
| pp32768 @ d8192 | 697.6 | 697.6 |
| pp32768 @ d32768 | 431.6 | 431.6 |
| pp65536 @ d32768 | 346.3 | 346.3 |

### Decode, t/s (codice)

| | master (no spec) | ours (n-max 3) |
|---|---:|---:|
| senza spec / con spec | 34.1 | **152.5** (acc 89%; "codice-bis" 143.6) |
| ragionamento | 34.1 | 103-134 (n4 meglio sullo spec) |

Altri cambi: mmproj su **CPU** (175 MB VRAM liberati), ngram 24/48/64 (erano 24/24/86),
spec-draft-n-max **3** (era 2). Contesto 160k invariato.

## Configurazione: `gemma-4-e4b`

Backend **Vulkan** in entrambi i casi.

| metrica | master | ours |
|---|---|---|
| prefill pp8192 @ d8192 | 2156.9 | 2156.9 |
| prefill pp16384 @ d8192 | 1910.0 | 1910.0 |
| decode codice (no spec -> spec) | 69.6 | 118-243 (rumore alto) |
| mmproj | **GPU (991 MB)** | **CPU** (~1 GB VRAM liberata) |
| contesto | 16k | 16k |

## Infrastruttura / servizio

| | master | ours |
|---|---|---|
| binario | Vulkan-only, statico, 54 MB | **HIP+Vulkan** statico, 145 MB, backup `llama-vulkan-old` |
| routing backend | implicito (Vulkan) | **`device = ROCm0` / `Vulkan0` per modello** |
| comando serve | `--models-max 2 --threads 12 ...` | **`--models-max 1`**, `--threads` fuori dal CLI |
| stabilita' swap | con 2 modelli residenti: errori OOM/`device lost` sulle transizioni ROCm<->Vulkan | 5/5 swap ok (4-13 s) |
| riuso prompt multi-turn | gia' attivo (`cache_prompt` default on) | invariato: 11.5k token -> 21 s freddo, **0.25 s** con prefisso |
| tracciabilita' | - | branch `rx9060xt/*`, 43 file di misure, `RESULTS.md`, `REPORT.md` |

## Esperimenti scartati (tutti misurati, nessuno adottato)

| esperimento | esito |
|---|---|
| FA dkq256 (head 256, LDS bypass) | +0.9%/+1.4% sul prefill math a profondita' -> sotto la soglia 3-5% |
| FA dkq256 su gemma | no-op (head 512 sui layer globali, 5/6 SWA) |
| GDN chunked (PR 29353) | gated a RDNA3.5; il kernel non ha device code per gfx12 |
| MTP adattivo (PR 27210) | applica e builda, ma rs cache da ~8 GB -> non entra |
| DFlash `incoai/Qwen3.8-27B-DFlash2` | rs cache da 9.5 GB anche a 16k -> inutilizzabile |
| binario lemonade/TheRock (Clang 24) | prefill +5%, decode -14% a profondita' -> no |
| TOP_K (PR 28313) | costo in microsecondi; su ROCm il perf mode crasha (grafi HIP rotti per TOP_K) |
| PR 29536 (spill VGPR MMQ) | -1.4% (col compilatore AMD non c'e' spill) |
| MMQ J=256 (dequant halving) | **-17%** (meta' dei blocchi = meno parallelismo) |
| tabelle MMQ RDNA4 vs RDNA3.5 | identiche a J=128 -> no-op |
| sweep b/ub | ub=512 e' gia' ottimale (440 vs 429 vs 417 t/s) |
| knob Vulkan (`ALLOW_GRAPHICS_QUEUE`, `DISABLE_ASYNC`, `DISABLE_COOPMAT`) | default ottimale; disabilitare coopmat dimezza il prefill |

## Come e' stato misurato

- `llama-bench` per prefill/decode (suite base, scale, sweep) - `benches/rx9060xt/bench-models.sh`.
- `llama-server` + prompt fissi (codice / ragionamento / codice ripetuto) per lo spec
  decoding, con `draft_n`/`draft_n_accepted` dai timings - `bench-spec.sh`, `bench-mtp-ab.sh`.
- `test-backend-ops` per la correttezza di ogni patch (`MUL_MAT`, `FLASH_ATTN_EXT`,
  `GATED_DELTA_NET`) - tutte verdi prima di ogni misura.
- Varianza: le righe con prompt grande sono stabili a +-0.1%; la prima riga della suite
  (`pp512 @ d8192`) puo' variare fino al ~12% tra binari identici -> non usata per decisioni.
  I numeri di decode con spec dipendono dall'acceptance del testo generato: vanno letti
  come fasce, non come valori esatti.
