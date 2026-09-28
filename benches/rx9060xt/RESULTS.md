# RX 9060 XT 16GB - risultati benchmark

Log cumulativo delle misurazioni. Ogni blocco riporta commit, configurazione di build,
variabili d'ambiente e parametri di test. I file grezzi di `llama-bench` sono in
`benches/rx9060xt/results/`.

## Ambiente

| voce | valore |
|---|---|
| GPU | AMD Radeon RX 9060 XT 16GB, gfx1200 (Navi 44), 16304 MiB VRAM, PCIe 5.0 x16 |
| CPU | Intel Core i5-13400F (6P+4E, 16 thread) |
| RAM | 32 GiB |
| ROCm | 7.2.4 in `/opt/rocm`, LLVM 22 (`/opt/rocm/lib/llvm/bin/clang`) |
| Vulkan | Mesa RADV (loader 1.4.357), glslc distro |
| Env globali | `LLAMA_CACHE=/home/alessandro/mnt/speed/models`, `ROCM_PATH=/opt/rocm`, `HSA_OVERRIDE_GFX_VERSION=12.0.0` (no-op: arch nativa gfx1200) |

Modelli (via `LLAMA_CACHE`):
- math = `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S` (11.28 GiB, arco `qwen35`, ibrido SSM+attention, MTP integrato)
- g12 = `unsloth/gemma-4-12B-it-qat-GGUF:UD-Q4_K_XL` (6.24 GiB, **Q4_0** "smart QAT", non Q4_K)
- g4 = `unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL` (3.91 GiB, Q4_0)
- draft disponibili: `mtp-gemma-4-12B-it.gguf` (254 MB), `mtp-gemma-4-E4B-it.gguf` (60 MB),
  DFlash g12 `gemma-4-12B-it-DFlash-Q4_K_M.gguf` (442 MB)

## Build

Commit base: `6c7a87f7e` (upstream), branch di lavoro `rx9060xt/integration`.

| build dir | backend | flag principali |
|---|---|---|
| `build-hip` | ROCm/HIP | `-DGGML_HIP=ON -DGPU_TARGETS=gfx1200 -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang -DGGML_CUDA_FA_QUANTS=f16-f16;q4_0-q4_0;q8_0-q8_0;bf16-bf16;q8_0-q4_0` |
| `build-vulkan` | Vulkan | `-DGGML_VULKAN=ON` |

Entrambe: `-DCMAKE_BUILD_TYPE=Release`, Ninja, ccache. Ricomando: `benches/rx9060xt/build.sh hip|vulkan`
(con `BUILD_SUFFIX` per i patch branch).

## Metodo

- `bench-models.sh` (llama-bench): suite `base` (-p 512/2048/8192 -n 128) e `scale`
  (-p fino a 65536, -d 8192/32768, REPS=2), FA on, KV da preset, `-t 12`, `-ngl` da preset.
- VRAM libera durante le misure (server llama spento).
- `bench-spec.sh` (llama-server): spec decoding, timings + draft acceptance.

## Confronto backend - suite base (-p 512/2048/8192 -n 128)

| modello | test | HIP | Vulkan | delta |
|---|---:|---:|---:|---:|
| math | pp512 | 498 | 623 | +25% |
| math | pp8192 | 590 | 587 | -1% |
| math | tg128 | 20.0 | 21.8 | +9% |
| g12 | pp512 | 1600 | 1533 | -4% |
| g12 | pp8192 | 1270 | 1291 | +2% |
| g12 | tg128 | 36.0 | 37.2 | +3% |
| g4 | pp512 | 3528 | 2558* | -27%* |
| g4 | pp8192 | 2932 | 2914 | -1% |
| g4 | tg128 | 63.0 | 74.3 | +18% |

\* primo test dopo il load, rumoroso (pp2048 Vulkan 3343): da non considerare.

## Confronto backend - suite scale (profondita' e prompt lunghi, HIP vs Vulkan)

math (IQ3_S, ctk q8_0 / ctv q4_0, ngl 99):

| test | HIP | Vulkan | delta |
|---|---:|---:|---:|
| pp512 @ d8192 | 490.7 | 473.5 | -3% |
| pp8192 @ d8192 | 545.0 | 501.1 | -8% |
| pp32768 @ d8192 | 489.9 | 414.5 | -15% |
| pp65536 @ d8192 | 430.8 | 334.9 | -22% |
| pp512 @ d32768 | 446.2 | 344.5 | -23% |
| pp8192 @ d32768 | 443.2 | 352.5 | -20% |
| pp32768 @ d32768 | 406.1 | 303.7 | -25% |
| pp65536 @ d32768 | 364.8 | 188.4 | **-48%** |
| tg128 @ d8192 | 19.0 | 21.4 | +13% |
| tg128 @ d32768 | 16.1 | (vedi file) | - |

g12 (Q4_0, ctk q8_0 / ctv q4_0, ngl 999):

| test | HIP | Vulkan | delta |
|---|---:|---:|---:|
| pp8192 @ d8192 | 905.8 | 966.2 | +7% |
| pp32768 @ d8192 | 631.1 | 697.6 | +11% |
| pp65536 @ d8192 | 447.8 | 494.3 | +10% |
| pp8192 @ d32768 | 483.2 | 539.1 | +12% |
| pp32768 @ d32768 | 391.0 | 431.6 | +10% |
| pp65536 @ d32768 | 312.0 | 346.3 | +11% |
| tg128 @ d8192 | 34.3 | 35.5 | +4% |
| tg128 @ d32768 | 30.4 | (vedi file) | - |

g4 (Q4_0, ctk/ctv q4_0, ngl 999, @ d8192):

| test | HIP | Vulkan | delta |
|---|---:|---:|---:|
| pp8192 | 2030.2 | 2156.9 | +6% |
| pp16384 | 1768.8 | 1910.0 | +8% |
| tg128 | 56.4 | (vedi file) | - |

## Decisione backend (provvisoria, pre-patch)

- **math -> HIP**: prefill in profondita' nettamente migliore (fino al doppio a 64k ingestiti
  a profondita' 32768); decode ~11% piu' lento.
- **g12 -> Vulkan**: prefill in profondita' +10%, decode leggermente meglio.
- **g4 -> Vulkan**: prefill +6/8%, decode migliore.
- Conseguenza: serve una **build combinata** (HIP+Vulkan) con selezione per modello via
  `device = ROCm0|Vulkan0` nei preset.
- La patch FA dkq256 (HIP, gemma) va misurata contro Vulkan come riferimento: se HIP+patch
  supera Vulkan sul prefill profondo dei gemma, il quadro puo' cambiare.

## Speculative decoding (prompt: continuazione di codice, /completion 192 token, c 32768)

| modello | config | pred t/s | accept | delta |
|---|---|---:|---:|---:|
| math (HIP) | none | 19.6 | - | - |
| math | draft-mtp n-max 2 | 34.4 | 83.2% | +76% |
| math | draft-mtp n-max 4 | 32.0 | 67.8% | +63% |
| math | **draft-mtp + ngram-mod** | **89.0** | 82.5% | **+354%** |
| g12 (Vulkan) | none | 34.1 | - | - |
| g12 | draft-mtp n-max 2 (mtp sidecar) | 59.1 | 67.3% | +73% |
| g12 | draft-mtp n-max 4 | 50.3 | 43.2% | +47% |
| g12 | ngram-mod (24/48/64) | 111.0 | 94.2% | +225% |
| g12 | **draft-mtp + ngram-mod** | **117.5** | 74.5% | **+245%** |
| g12 | draft-dflash (williamliao) n-max 15 | 18.0 | **0.9%** | -47% (inutilizzabile) |
| g4 (Vulkan) | none | 69.6 | - | - |
| g4 | draft-mtp n-max 2 | 126.5 | 71.7% | +81% |
| g4 | **draft-mtp + ngram-mod** | **212.3** | 56.9% | **+204%** |

Note:
- Il prompt di test e' una continuazione di codice: e' lo scenario migliore per ngram-mod
  (testo ripetitivo). In chat/reasoning il guadagno sara' inferiore, ma per i flussi
  agentici su codice e' rappresentativo.
- `ngram-mod` con 24/48/64 va meglio dei parametri attuali dei preset (24/24/86).
- Il draft DFlash di williamliao non e' compatibile (acceptance ~1%): scartato.
- math: MTP e' **spento** nel preset attuale; accenderlo e' il singolo guadagno piu' grosso.
- Le run con ngram hanno alta varianza (dipende da quanto il testo ripete).

## Patch candidate (branch dedicati) - esiti

| branch | patch | esito |
|---|---|---|
| `rx9060xt/patch-fa-dkq256` | PR 26419: WMMA FA head dim 256 + K/V bypass LDS su RDNA4 | **corretta ma nessun guadagno** su g12/g4 (numeri identici al baseline). Motivo: gemma-4 ha head_dim 512 nei layer globali (la patch copre <=256) e 5/6 dei layer sono sliding-window da 1024 token -> l'attenzione non e' il collo di bottiglia del prefill (domina il matmul). Non adottata. |
| `rx9060xt/patch-gdn-chunked` | PR 29353: kernel GDN chunked per il prefill | **no-op su gfx1200**: il path HIP e' gated a RDNA3.5 (`select_gdn_mma_path`) e richiede n_tokens >= 2048. Correttezza OK (45/45). Tentativo di abilitarlo su RDNA4 (commit `f80830ce9`): il kernel e' compilato solo sotto `AMD_WMMA_AVAILABLE && RDNA3` -> a runtime "HIP kernel gdn_single has no device code compatible with HIP arch 1300". Serve un port vero delle WMMA per gfx12 (layout diversi), fuori scope. |

Nessuna delle due patch e' quindi adottata: i guadagni rimasti sono lato configurazione
(spec decoding, batch/KV, cache, scelta backend per modello).

## Note di misura (varianza)

- Le righe con prompt grande (pp8192+) sono molto stabili tra run (tipicamente +-0.1%).
- La **prima** riga della suite scale (`pp512 @ d8192`) ha mostrato fino a **+12% di
  differenza tra due build identiche** (490 vs 550 t/s): da considerare inaffidabile,
  non usarla per decisioni. Le stesse righe su Vulkan mostrano lo stesso pattern.
- Le righe `tg128` sono stabili entro ~1%, tranne alle profondita' maggiori (~2-3%).

## Log sessioni

### 2026-09-28
- baseline HIP: `results/hip-all-base-20260928-172706.md`, `results/hip-{math,g12,g4}-scale-*.md`
- baseline Vulkan: `results/vulkan-all-base-20260928-173038.md`, `results/vulkan-{math,g12,g4}-scale-*.md`
- patch FA dkq256: `results/hip-fa-g12-scale-20260928-193029.md` (identico al baseline)
- patch GDN: `results/hip-gdn-math-scale-20260928-195807.md` (differenze = solo rumore)
- `-nkvo` e spec decoding: in coda.

## Da fare

- [x] build+bench patch FA dkq256 (no win) e patch GDN (no-op su gfx1200)
- [x] spec decoding matrix: math MTP (da accendere), g12/g4 MTP+ngram-mod; DFlash scartato
- [ ] applicare le config vincenti in preset.ini (mmproj su CPU, device per modello, spec)
- [ ] sweep b/ub, threads, cache-ram/cache-reuse
- [ ] A/B con binario prebuilt lemonade (TheRock, Clang 24) - scaricato in
      `~/.cache/llamacpp-rocm-b1333/extracted`
- [ ] misura `-nkvo` (muro PCIe per KV in RAM)
- [ ] install finale (build combinata) + validazione end-to-end

## Harness

- `build.sh hip|vulkan|both` (env `BUILD_SUFFIX` per build dir separate)
- `bench-models.sh <build> <label> <modello|all> <suite>` - suite: base, scale, kv, batch,
  threads, fa, nkvo
- `bench-spec.sh <build> <label> <modello> <nome> -- <args>` - spec decoding via server
- `bench-spec-matrix.sh <build> <label> [math|g12|g4|all]` - matrice di configurazioni spec
- `bench-cache.sh <build> <label> <modello> <nome> -- <args>` - riuso prompt multi-turn
- `install.sh <build-dir>` - installa in ~/.local/bin con backup

## Convenzioni

- `master` = upstream pulito; lavoro su `rx9060xt/*` (integrazione: `rx9060xt/integration`).
- Un commit per esperimento; before/after nei messaggi di commit per le patch di codice.
- Risultati grezzi in `results/`, questo file e' il riepilogo cumulativo.
