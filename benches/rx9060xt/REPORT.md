# Report finale: master vs ours (RX 9060 XT 16 GB, gfx1200)

> Nota importante: **il codice e' upstream in entrambi i casi**. Dopo i test, nessuna
> delle patch di codice e' stata adottata (tutte sotto soglia o non applicabili, vedi
> "Esperimenti scartati"). La differenza "ours" sta in: scelta del backend per modello,
> flag di build, e preset (contesto, KV, np, spec, mmproj). Il confronto quindi e'
> **setup di partenza (binario Vulkan + preset originali)** vs **setup attuale**.

Dati grezzi: `benches/rx9060xt/results/*.md` (43 file). Riepilogo cumulativo: `RESULTS.md`.
Preset finale: `preset.final.ini` (copia di `~/.config/llama.cpp/preset.ini`).

## Configurazioni definitive (complete) per modello e backend

Tutte le voci qui sotto sono **testate**. Quelle marcate *spedita* sono nel preset
attivo (`preset.final.ini` = `~/.config/llama.cpp/preset.ini`); le altre sono le
controprove sull'altro backend (stessi flag, cambia solo `device`).

### Comuni a tutte le voci

| parametro | valore |
|---|---|
| build | `benches/rx9060xt/build.sh both` (HIP+Vulkan, statico) |
| `[*] c` / `ctk` / `ctv` | 128000 / q8_0 / q8_0 (i modelli sotto li sovrascrivono dove indicato) |
| `jinja` / `reasoning-preserve` | true / true |
| `chat-template-kwargs` | `{"reasoning_effort": "high"}`; math usa `xhigh` |
| mmproj | **sempre su CPU** (`no-mmproj-offload = true`) |
| KV draft (MTP) | `q4_0` / `q4_0` |
| ngram (dove attivo) | n-match 24, n-min 48, n-max 64 |
| comando serve | `llama serve --models-preset ~/.config/llama.cpp/preset.ini --models-max 1 --tools all --port 8181 --host 127.0.0.1` |

### `math-38-27b` (Qwen3.8-27B)

| parametro | IQ3_S su **ROCm** *spedita* | IQ3_S su **Vulkan** *spedita (long)* | IQ3_XXS su ROCm *spedita* | IQ3_XXS su Vulkan *spedita* |
|---|---|---|---|---|
| sezione preset | `math-38-27b` | `math-38-27b-long` | `math-38-27b-xxs` | `math-38-27b-xxs-vk` |
| `device` | ROCm0 | Vulkan0 | ROCm0 | Vulkan0 |
| contesto | **98304** | 128000 | **131072** | 131072 |
| `np` | **1** | 1 | **1** | 1 |
| KV | K q8_0 / V q4_0 | K q8_0 / V q4_0 | K q8_0 / V q4_0 | K q8_0 / V q4_0 |
| `ngl` / `fa` / `fit` | 99 / on / on | idem | idem | idem |
| `b` / `ub` | 8192 / 512 | idem | idem | idem |
| spec | `draft-mtp,ngram-mod`, n-max **2** | idem | idem | idem |
| `threads` | 8 / 8 | 8 / 8 | 8 / 8 | 8 / 8 |
| cache | cache-prompt on, cache-reuse 0, cache-ram 0, no-cache-idle-slots | idem | idem | idem |
| sampling | temp 1.0, top-p .95, min-p 0, top-k 20, presence 0, repeat 1.0 | idem | idem | idem |
| reasoning-budget | 15000 + messaggio | idem | idem | idem |
| VRAM a carico (MTP on) | 15.29 GiB | 15.25 GiB | 14.88 GiB | 13.68 GiB |

### `gemma-4-12b`

| parametro | su **Vulkan** *spedita* | su **ROCm** (controprova) |
|---|---|---|
| `device` | Vulkan0 | ROCm0 |
| contesto | 160000 | 160000 |
| `ngl` / `fa` | 999 / on | idem |
| KV | K q8_0 (da `[*]`) / V q4_0 | idem |
| spec | `draft-mtp,ngram-mod`, **n-max 3**, `spec-draft-p-min 0.1`, `-md mtp-gemma-4-12B-it.gguf` (auto dal router) | idem |
| `threads` | 16 / 16 | idem |
| cache / sampling | cache-prompt on; temp .7, top-p .95, top-k 64 | idem |
| reasoning-budget | 10000 + messaggio | idem |
| VRAM a carico (MTP on) | **8.20 GiB** | 8.95 GiB |

### `gemma-4-e4b`

| parametro | su **Vulkan** *spedita* | su **ROCm** (controprova) |
|---|---|---|
| `device` | Vulkan0 | ROCm0 |
| contesto | 16000 | 16000 |
| `ngl` / `fa` | 999 / on | idem |
| KV | q4_0 / q4_0 | idem |
| spec | `draft-mtp,ngram-mod`, n-max 2, p-min 0.1, `-md mtp-gemma-4-E4B-it.gguf` | idem |
| `threads` | 8 / 8 | idem |
| cache / sampling | cache-prompt on, cache-reuse 0, cache-ram 0, no-cache-idle-slots; temp 1.0, top-p .95, top-k 64 | idem |
| reasoning-budget | 1000 + messaggio | idem |
| VRAM a carico (MTP on) | **2.80 GiB** | 3.16 GiB |

(Il `device` e' l'unica differenza tra le due colonne: sono le configurazioni usate
nella matrice qui sotto.)

## Matrice completa: backend x modello x profondita' x tipo di testo x VRAM

Misurata con un unico binario (HIP+Vulkan) selezionando `--device`, stesso KV,
stessi flag MTP (n-max per modello), `np=1`. File grezzo: `results/matrix-*.md`.

### Prefill, t/s (llama-bench, pp8192 a profondita' crescente)

| config | ctx | d0 | @d8192 | @d32768 |
|---|---:|---:|---:|---:|
| math IQ3_S ROCm | 96k | 594.6 | 546.7 | **442.7** |
| math IQ3_S Vulkan | 128k | 585.8 | 500.5 | 351.7 |
| math IQ3_XXS ROCm | 128k | 521.9 | 485.1 | 400.8 |
| math IQ3_XXS Vulkan | 128k | 594.2 | 506.5 | 354.4 |
| g12 ROCm | 160k | 1267.4 | 903.8 | 482.7 |
| g12 Vulkan | 160k | 1286.6 | **964.4** | **538.0** |
| g4 ROCm | 16k | 2908.7 | 2025.2 | - |
| g4 Vulkan | 16k | 2907.0 | **2150.7** | - |

- math: pari a contesto vuoto, **ROCm +26% a 32k di profondita'** (e il divario cresce);
  l'IQ3_XXS paga ~9% di prefill rispetto all'IQ3_S su ROCm (mix di tensor diverso per MMQ),
  ma libera ~1 GB di VRAM.
- g12: **Vulkan avanti a tutte le profondita'** (+2% / +7% / +11%).
- g4: pari a vuoto, **Vulkan +6% a 8k**.

### Decode, t/s (192 token, greedy) - spec OFF -> spec ON (MTP+ngram)

| config | VRAM a carico (off -> on) | codice | ripetitivo | prosa |
|---|---|---:|---:|---:|
| math IQ3_S ROCm 96k | 13.99 -> 15.29 GiB | 19.5 -> 31.5 | 19.8 -> 46.5 | 19.8 -> 34.8 |
| math IQ3_S Vulkan 128k | 14.29 -> 15.25 GiB | 20.7 -> 34.1 | ferma subito (EOS) | 20.9 -> 37.1 |
| math IQ3_XXS ROCm 128k | 13.39 -> **14.88 GiB** | 20.4 -> **67.1** | 20.7 -> 34.9 | 20.7 -> 31.8 |
| math IQ3_XXS Vulkan 128k | 12.73 -> **13.68 GiB** | 22.9 -> 63.4 | 23.0 -> 40.8 | 23.1 -> 36.0 |
| g12 ROCm 160k | 8.22 -> 8.95 GiB | 34.1 -> 102.0 | 34.8 -> **194.0** | 35.3 -> 229.3 |
| g12 Vulkan 160k | **7.77 -> 8.20 GiB** | 33.8 -> **147.7** | 34.3 -> 81.1 | 34.8 -> **256.4** |
| g4 ROCm 16k | 3.02 -> 3.16 GiB | 58.5 -> 101.7 | 60.6 -> 116.5 | 61.8 -> 71.8 |
| g4 Vulkan 16k | **2.72 -> 2.80 GiB** | 69.0 -> **113.9** | 68.6 -> **142.9** | 70.3 -> **85.9** |

Letture:
- **MTP aiuta su tutti i tipi di testo**, ma con ampiezze molto diverse: sul ripetitivo
  (log/CSV) e sulla prosa i draft vengono accettati molto piu' spesso che sul codice
  "nuovo" (acceptance 30% sul codice vs 90-99% su ripetitivo/prosa per g12).
- **Il contesto MTP costa VRAM**: +1.2-1.3 GiB sul math (SSM, IQ3_S e XXS), +0.73/0.43
  GiB su g12, +0.14/+0.08 su g4. Sul math e' il vincolo che limita contesto e profondita'.
- **IQ3_XXS conviene se conta la VRAM**: 13.68 GiB su Vulkan (il piu' basso dei math)
  contro 15.25 dell'IQ3_S, e permette 128k su ROCm dove l'IQ3_S si ferma a 96k; il
  prefill pero' e' ~9% piu' lento su ROCm. IQ3_S resta la scelta "qualita'".
- **g4: Vulkan vince su tutto** (piu' veloce e ~0.3 GiB in meno). g12: Vulkan vince su
  codice/prosa e sul prefill, ROCm sul ripetitivo (194 vs 81) — ma il prefill profondo
  resta il discriminante stabile, quindi Vulkan.
- math: a contesto vuoto sono pari; a profondita' ROCm vince. L'unico artefatto e' il
  prompt ripetitivo su Vulkan, dove il modello emette EOS al primo token (differenza
  numerica tra kernel: nessun errore, semplicemente non genera).

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
