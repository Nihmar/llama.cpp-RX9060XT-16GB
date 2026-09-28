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

## Validazione end-to-end e nota importante sul router

Problema trovato: con backend diversi per modello (math su ROCm, gemma su Vulkan) il router
con `--models-max 2` tiene **due modelli residenti**; su ROCm non c'e' overcommit della VRAM
(a differenza di Vulkan, che sfutta la GTT), quindi il secondo caricamento fallisce con
"unable to allocate ROCm0 buffer" (500) e in un caso anche "device lost" su Vulkan.

Soluzione: **`--models-max 1`**. Verificato: 5/5 richieste ok alternando
math(ROCm) -> g12(Vulkan) -> math-long(Vulkan) -> e4b(Vulkan) -> math(ROCm), 4-13 s per swap.

Prova: `benches/rx9060xt/validate.sh` (4 modelli, controlla anche i `--device` dei figli).

## Comando serve finale

```bash
llama serve --models-preset ~/.config/llama.cpp/preset.ini --models-max 1 \
  --tools all --port 8181 --host 127.0.0.1
```

(`--threads 12` rimosso: sovrascriveva i `threads` dei preset.)

## MTP adattivo (PR 27210) - valutato, non adottato

La patch applica pulita sul nostro tree (branch `rx9060xt/patch-mtp-adaptive`,
commit `4e2b3d639`) e builda. Ma sul nostro hardware non e' percorribile:

- con `--spec-type draft-mtp-adaptive --spec-draft-n-max 12` il contesto MTP
  non entra in VRAM: a 90k fallisce l'allocazione dei compute buffer, a 72k
  addirittura la **rs cache da ~8 GB** (il batch di verifica ampio moltiplica
  lo stato ricorrente dell'SSM; il contesto MTP ha la sua copia).
- gia' il MTP fisso a n-max 3 non entra a 110k (serve ~630 MB in piu' dei n-max 2).
- l'upstream l'ha misurato su 2x R9700 da 32 GB: li' c'e' spazio per i draft profondi.

Conclusione: con un 27B ibrido SSM su 16 GB, il tetto pratico per il MTP e'
**n-max 2**; la profondita' adattiva non ha spazio per esprimersi. Il branch
resta come riferimento per il futuro (es. con un modello non-SSM, dove lo stato
ricorrente non moltiplica la memoria, o su GPU con piu' VRAM).

Confronto fixed-n2 misurato (math XXS, 110k/90k, stessi prompt): 67.6-68.0 t/s
codice, 32.6-32.7 ragionamento, 164.7-165.0 codice ripetuto — riproducibile
entro l'1%.

## TOP_K su ROCm: costo irrilevante, ma grafi HIP rotti per quell'op

Misurato con `test-backend-ops perf -o TOP_K`:

- Vulkan: 2.0-27.6 us/run su tutte le forme testate (ne 2..65536, k 1..400).
- ROCm: **SIGSEGV al secondo caso**, durante il "CUDA graph warmup" (la modalita'
  test senza grafi passa 525/525). Coerente con la nota nel PR 28313: l'update
  dei grafi HIP e' rotto upstream per TOP_K (in attesa di ROCm/rocm-systems#11069).

Implicazioni: (a) il TOP_K non e' un collo di bottiglia per noi (us e' <0.5% di un
token a 30 t/s), quindi il PR 28313 non serve; (b) se in futuro si abilita il
**backend sampling** su ROCm conviene anche `GGML_CUDA_DISABLE_GRAPHS=1`, perche'
quel percorso puo' toccare TOP_K con i grafi attivi.

## Variante IQ3_XXS del math (risparmio ~1 GB di pesi)

La rs cache SSM (~1.8 GB) + MTP non entravano a contesto pieno con IQ3_S. Con IQ3_XXS
(repo `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_XXS`, file `-mtp`) si guadagnano ~1 GB:

| config | ctx | esito |
|---|---:|---|
| ROCm + MTP + K q8_0 | 128k | fallisce la creazione del contesto MTP (mancano ~750 MB) |
| ROCm + MTP + K q8_0 | 120k | carica ma **crash alla prima inferenza** (`CUBLAS_STATUS_ALLOC_FAILED`, workspace hipBLAS) |
| ROCm + MTP + K q8_0 | **110k** | **ok** (configurazione scelta) |
| Vulkan + MTP + K q8_0 | **128k** | **ok** |

Decode misurato (XXS, 192 token, /completion, temp 0):

| scenario | ROCm 110k | Vulkan 128k |
|---|---:|---:|
| codice, prima generazione | 67.9 t/s (acc 76%) | 53.7 t/s (acc 75%) |
| ragionamento libero | 32.6 t/s (acc 73%) | 32.2 t/s (acc 79%) |
| stesso codice rigenerato | 164.8 t/s (acc 98%) | - |

Lettura onesta: su contenuto nuovo il decode e' ~33-68 t/s (base senza spec: 20 t/s);
il picco ~165 t/s si ha solo quando il testo si ripete (il pool ngram condiviso ha gia'
visto gli stessi token), tipico del lavoro iterativo su codice.

## math: contesto vs MTP (VRAM 16 GB, KV q8_0/q4_0 salvo dove indicato)

Il math e' ibrido SSM: la rs cache (stato ricorrente) occupa ~1.8 GB fissi e con MTP
serve una seconda copia. Con `ngl 99` (tutto su GPU) su ROCm:

| config | ctx | decode t/s | accept | prefill t/s | note |
|---|---:|---:|---:|---:|---|
| ROCm, senza MTP | 128k | 19.6 | - | 590 | configurazione originale (funziona) |
| ROCm + MTP | 72k | 82.9 | 81.5% | 531 | massimo contesto con K q8_0 |
| ROCm + MTP, K q4_0 | 96k | 73.4 | 64.9% | 552 | K q4_0 per far entrare la KV |
| Vulkan + MTP | 128k | 38.8 (28.9-48.6) | 44.9% | 515-524 | tiene 128k con K q8_0 |
| ROCm + MTP + KV su host (`--no-kv-offload`) | 128k | 17.8 | 58.8% | **221** | inutilizzabile: prefill via PCIe |
| ROCm + MTP, `fit` senza ngl | 128k | n/d | - | - | carica ma 43/66 layer su GPU |

Non entrano su ROCm con ngl 99: 128k + MTP (ne' con K q8_0 ne' q4_0), 96k/80k con K q8_0.

Scelte applicate nei preset:
- `math-38-27b`: ROCm, `c = 92160` (90k, margine sul 96k verificato), `ctk/ctv q4_0`, MTP+ngram
  -> ~73 t/s di decode (3.7x rispetto a prima) mantenendo un contesto ampio.
- `math-38-27b-long`: Vulkan, `c = 128000`, K q8_0, MTP+ngram -> 128k pieni, decode ~2x.

## Vulkan: i knob di ambiente non aiutano (il default e' ottimale)

A/B sulla suite base con gemma-4-12b (Vulkan/RADV):

| knob | pp512 @ d8192 | pp8192 @ d8192 | pp32768 @ d8192 | tg128 @ d8192 |
|---|---:|---:|---:|---:|
| default | 1031.7 | 962.5 | 697.6 | 35.3 |
| `GGML_VK_ALLOW_GRAPHICS_QUEUE=1` | 1003.1 | 955.5 | 693.9 | 36.2 |
| `GGML_VK_DISABLE_ASYNC=1` | 1000.1 | 947.8 | 688.5 | 35.1 |
| `GGML_VK_DISABLE_COOPMAT=1` | 539.8 | 504.8 | n/d | n/d |

- **coopmat1 e' decisivo**: disabilitarlo dimezza il prefill (-48%). Il percorso
  FA coopmat1 su RDNA4/RADV e' quello giusto e va lasciato attivo.
- gli altri knob sono entro +-1-3% e peggiorano il prefill; il +2.8% di decode
  di ALLOW_GRAPHICS_QUEUE e' dentro la varianza di misura.
- Verdetto: nessuna variabile d'ambiente da impostare per il lato Vulkan.

## Speculative decoding lato Vulkan (gemma) e confronto a parita' di config

- gemma-4-12b: su codice n-max 3 e' nettamente meglio di n2 (152/144 t/s con
  acceptance 89% contro 59/58 con 67%); su ragionamento vince n4 (134 vs 103).
  A differenza del math (SSM) qui i draft profondi non costano memoria
  (nessuna rs cache): preset portato a **n-max 3**.
- gemma-4-e4b: n2/n3/n4 indistinguibili (rumore di acceptance).
- Confronto a parita' di config su g12 (stessi flag spec): HIP 102-137 t/s
  codice / 134-147 ragionamento, Vulkan 152/103 — i numeri di spec decoding
  sono dominati dalla varianza di acceptance; il prefill (stabile) resta a
  favore di Vulkan (+10% in profondita'), quindi la scelta di backend per i
  gemma regge.

## MMQ: tre esperimenti, tutti negativi (asse chiuso su HIP)

1. **Tabelle RDNA4 vs RDNA3.5**: a J=128 (il nostro caso con M=512) usano la stessa
   riga `(256, 2, 128, 128)` -> nessuna differenza possibile.
2. **PR 29536 (VGPR)**: portata e misurata -> **-1.4%** (col compilatore AMD i
   kernel non spillavano).
3. **J=256** (dimezza il dequant ridondante; riga `(128,2,64,256)`, LDS 55.8 KB
   <= 64 KB): correttezza OK ma **-17%/-16%** (pp8192 @ d8192: 402 vs 485;
   pp32768 @ d8192: 371 vs 439 t/s). Con meta' dei blocchi si perde piu'
   parallelismo di quanto si guadagni in dequant: ecco perche' la soglia
   upstream e' J=128.

Conclusione: il prefill HIP e' gia' ben calibrato per i nostri quant misti
(IQ3_S/IQ3_XXS/IQ4_XS); il ~60% del picco MMA e' il tetto pratico.

## Patch MMQ VGPR (PR 29536) - testata, non adottata

Il PR e' minuscolo (2 file, 11 righe): i builtin bf16 WMMA prendono i bit come
vettori di short, e i loop k01 dei path MMQ q8_0/q8_1 restano rolled
(`#pragma unroll 1`) perche' sui kernel con J >= 80 le load hoisted sforano il
budget VGPR e spillano su RDNA4. Il nostro prefill sceglie **J = 128** per
IQ3_S/IQ3_XXS, quindi teoricamente eravamo nel caso peggiore.

Misurato (math XXS, pp @ d8192, r=3, correttezza MUL_MAT OK):

| build | pp8192 @ d8192 | pp32768 @ d8192 |
|---|---:|---:|
| baseline (build-hip) | 484.95 | 439.59 |
| con patch (build-hip-mmq) | 478.24 (-1.4%) | 434.27 (-1.2%) |

Conclusione: con il compilatore AMD (ROCm 7.2.4, clang 22) quei kernel **non
spillavano**; il `#pragma unroll 1` costa ~1%. Coerente con l'autore del PR
("the same as with AMD's compiler"). Non adottata; il branch resta come
riferimento per build con LLVM stock.

## Stato finale applicato (preset)

| voce | math-38-27b | math-38-27b-xxs | gemma-4-12b | gemma-4-e4b |
|---|---|---|---|---|
| backend | ROCm0 | ROCm0 | Vulkan0 | Vulkan0 |
| quant | IQ3_S | IQ3_XXS | Q4_0 (QAT) | Q4_0 (QAT) |
| contesto | 98304 (96k) | 131072 (128k) | 160000 | 16000 |
| np | 1 | 1 | default | default |
| KV | K q8_0 / V q4_0 | K q8_0 / V q4_0 | K q8_0 / V q4_0 | q4_0/q4_0 |
| spec | draft-mtp,ngram-mod n2 | idem | draft-mtp,ngram-mod n2 | idem |
| mmproj | CPU | CPU | CPU | CPU |
| decode misurato | 78 t/s (codice) | 68 t/s | 117 t/s | 212 t/s |

Il guadagno strutturale e' `np = 1`: la rs cache SSM si dimensiona come
`n_seq_max × (1 + n_max)` righe e llama-server default a `n_parallel = 4`.
Con np=1 si liberano ~1.4 GB, che abbiamo speso in contesto (96k/128k) e in K a
q8_0 invece di q4_0. n-max resta 2 perche' misurato ottimale.

## Roadmap ulteriore (analisi approfondita, in ordine di valore atteso)

1. **MMQ J=256** (dimezza il dequant ridondante: con M=512 e J=128 il dequant dei
   pesi si ripete 4 volte, una per j-tile; `mul_mat_q_switch_J` si ferma a 128).
   Costo: righe di tabella + `case 256` + estensione del loop; ~55.8 KB di LDS
   con I=64/J=256 sta nei 64 KB. Atteso 0-10% sul prefill. E' l'unico candidato
   MMQ rimasto dopo i test negativi (C1 era un no-op a J=128: le tabelle RDNA4 e
   RDNA3.5 coincidono li').
2. **GDN chunked su gfx12**: tetto 1-4% (il GDN e' piccolo rispetto all'FFN),
   costo 1-3 giorni di port dei layout WMMA. Non vale.
3. **FA dkq256 kernel-only sul math** (head_dim 256): tetto ~2% sul prefill.
4. **Vulkan (gemma)**: `GGML_VK_PERF_LOGGER=1` per il profilo per-op (da' forme FA
   e GFLOPS dei MUL_MAT) + A/B dei knob mai testati: `GGML_VK_ALLOW_GRAPHICS_QUEUE`,
   `GGML_VK_DISABLE_ASYNC`, `GGML_VK_DISABLE_COOPMAT`, `GGML_VK_DISABLE_MMVQ`.
   Percorso FA attuale: coopmat1 in prefill; in decode coopmat1 per i layer GQA e
   scalar per quelli a KV pieno.
5. **Sistema**: verificare il performance level con `rocm-smi --showclocks
   --showpower` (se e' in auto, forzare high), env `HSA_ENABLE_SDMA`,
   `GPU_MAX_HW_QUEUES`, e threads/pinning CPU (conta per mmproj su CPU).

Dove va il tempo (analisi del codice + misure): il prefill del math e' dominato
dai **matmul** (FFN ~2/3 dei FLOP; attenzione ~5% a 32k di profondita'; GDN 1-4%)
e giriamo a ~60% del picco MMA int8-equivalente. Il decode e' limitato
dall'acceptance dello spec e dalla VRAM, non dai kernel.

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
