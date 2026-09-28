# Ottimizzazione llama.cpp per Radeon RX 9060 XT 16GB (gfx1200)

> Piano approvato. Copia di lavoro dentro il fork; l'originale e' in `~/.commandcode/plans/rx9060xt-llamacpp-optimization.md`.

## Obiettivo
Massimizzare le prestazioni (bilanciate prefill + generazione) dei 3 modelli target su RX 9060 XT 16GB:
- **math-38-27b** (`ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S`, arco `qwen35` ibrido SSM+attention, MTP integrato)
- **gemma-4-12b** (`unsloth/gemma-4-12B-it-qat-GGUF:UD-Q4_K_XL`, MTP sidecar 254MB)
- **gemma-4-e4b** (`unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL`, MTP sidecar 60MB)

Decisione ROCm vs Vulkan guidata dai benchmark, con **scelta per-modello** (build unica con entrambi i backend, selezione via `device` nei preset). Patch al codice gfx1200 solo se i dati mostrano un guadagno chiaro, come commit isolati.

## Stato attuale (verificato)
- **Fork**: `/home/alessandro/Projects/llama.cpp-RX9060XT-16GB`, upstream puro (0 commit custom), commit `6c7a87f7e`. Nessuna build dir esistente.
- **Produzione attuale**: `~/.local/bin/llama` (build **Vulkan**, 54MB) avviato come:
  `llama serve --models-preset ~/.config/llama.cpp/preset.ini --models-max 2 --threads 12 --tools all --port 8181`
  Il router spawna un child per modello; **`--threads 12` del CLI sovrascrive i `threads` dei preset** (verificato nei cmdline reali dei child).
- **HW**: GPU gfx1200 (Navi 44), 15.92 GiB VRAM (ora ~13.9GB usati: gemma-12b + e4b + desktop). CPU i5-13400F (6P+4E/16t), 32GB RAM (~16GB liberi).
- **ROCm 7.2.4** in `/opt/rocm` (LLVM 22; cmake hip/hipblas/rocblas/hipblaslt presenti; Tensile gfx1200 ok).
- **Vulkan**: solo ICD RADV (Mesa), loader+glslc+vulkaninfo ok; `vulkan-headers` e `spirv-headers` installati.
- **Env globali (fish)**: `LLAMA_CACHE=/home/alessandro/mnt/speed/models`, `HSA_OVERRIDE_GFX_VERSION=12.0.0`, `ROCM_PATH=/opt/rocm`.
- **preset.ini** (`~/.config/llama.cpp/preset.ini`): `fit=on` e' **no-op** dove `ngl` e' impostato (fit aborta, `common/fit.cpp:463-465`). Tutti e tre i target hanno `ngl=99/999` espliciti. Spec: gemma usano `draft-mtp,ngram-mod`; **math ha `draft-mtp` commentato**. `cache-ram=0`, `cache-reuse=0`, `no-cache-idle-slots` → nessun riuso prompt.
- **Extra in cache**: draft DFlash per gemma-4-12b (`williamliao/gemma-4-12B-it-DFlash-GGUF`, 442MB) non usato.

## Fase 0 - Prerequisiti e baseline
1. Installare: `sudo pacman -S vulkan-headers spirv-headers` (+ `ccache` consigliato, `vulkan-validation-layers` opzionale). FATTO.
2. Baseline: salvare la config effettiva dei child del router e una **build Vulkan del commit corrente** per avere `llama-bench` e un riferimento A/B pulito.
3. Verificare con `rocminfo` l'arch nativa con e senza `HSA_OVERRIDE_GFX_VERSION=12.0.0` (attesa gfx1200).

## Fase 1 - Build (Ninja, Release, ccache)
- **build-hip**: `-DGGML_HIP=ON -DGPU_TARGETS=gfx1200 -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang`. `-j10`.
- **build-vulkan**: `-DGGML_VULKAN=ON`.
- **build-both** (serve per la scelta per-modello): entrambi i flag; validare con `--list-devices` la presenza di `ROCm0` e `Vulkan0` e il funzionamento del key `device` nei preset.
- Salvaguardie: build in dir separate (`build-*`), mai toccare il server in esecuzione.

## Fase 2 - Benchmark A/B ROCm vs Vulkan (bilanciato pp+tg)
Per ciascun modello, con `llama-bench` (stessi quant/KV dei preset):
- Base: `-p 512,2048,8192 -n 128 -r 3`, FA on, KV dei preset.
- Varianti: FA off/on; ctk/ctv (q8_0/q8_0, q8_0/q4_0, q4_0/q4_0); b/ub (512/512, 2048/512, 4096/512, 8192/512); threads 8/12/16.
- Env test: `GGML_CUDA_DISABLE_GRAPHS` (HIP), `GGML_VK_ALLOW_GRAPHICS_QUEUE=1`, `GGML_VK_DISABLE_ASYNC`, `MESA_SHADER_CACHE_MAX_SIZE=4G`.
- VRAM: letture da `/sys/class/drm/card1/device/mem_info_vram_used` + size dai log di caricamento (KV cache, compute buffer).
- Output: tabella per modello → **vincitore per modello** (pp e tg valutati bilanciati).

## Fase 3 - Tuning preset.ini (backup: `preset.ini.bak-<data>`)
**math-38-27b**
- Abilitare `spec-type = draft-mtp` (MTP integrato, niente file extra); testare `spec-draft-n-max` 2/3/4, eventuale combo con `ngram-mod`.
- Risolvere fit/ngl: opzione A rimuovere `ngl` (fit decide layer+ctx), opzione B `ngl` esplicito + `fit=off`; scegliere con misure VRAM/ctx.
- Sweep b/ub; verifica ctk/ctv vs q4_0/q4_0; confermare tenuta 128k (log "KV cache size").
**gemma-4-12b**
- Spec: `draft-mtp` (attuale) vs `draft-dflash` (file gia' in cache) vs solo `ngram-mod` vs combo; tuning n-max/p-min/parametri ngram.
- Valutare ctk q8_0→q4_0; b/ub; threads.
**gemma-4-e4b**
- mmproj da 991MB: decidere se tenerlo offloaded in GPU o no in base all'uso reale della visione (VRAM libera).
- Proposta: alzare ctx da 16k (32-64k) se utile ai flussi.
**Router/serving**
- Spostare `--threads 12` fuori dal CLI del router (oggi sovrascrive i preset) o allineare i threads per modello.
- `--models-max 2`: documentare le coppie compatibili con 16GB (gemma-12b+e4b insieme; math da solo).
- Prompt cache (approvato): misurare TTFT multi-turn con `cache-ram=0` vs 4096/8192 e `cache-reuse` 256/512; attivare se il guadagno e' netto e la RAM lo consente; verificare interazione con `--models-max 2` e `no-cache-idle-slots`.

## Fase 4 - Patch mirate (solo se giustificate, ognuna commit isolato con bench before/after)
Candidati gia' individuati:
- **Vulkan**: pipeline q8_1 `q4_k`/`q5_k` saltate su RDNA4 (`ggml-vulkan.cpp` ~2483-2494) → test riabilitazione per gemma Q4_K (upstream le disattiva per lentezza: verificare).
- **HIP**: `nwarps` per vec_dot complessi su RDNA4 (`mmvq.cu` ~483-503) per IQ3_S.
- **HIP**: micro-tuning tabelle MMQ RDNA4 / FATTN solo se emerge un collo di bottiglia dai profili.
Regola: patch solo con guadagno >~5% e nessuna regressione; altrimenti scartate.

## Fase 5 - Installazione, verifica end-to-end, rollback
- Backup `~/.local/bin/llama` → `~/.local/bin/llama-vulkan-old`; installare `llama` + `llama-bench` nuovi (build combinata se scegliamo backend diversi per modello, con `device = ROCm0|Vulkan0` nei preset).
- Riavviare `llama serve` con la stessa riga; verificare: device nei log, VRAM, caricamento dei 3 modelli, TTFT e tg reali con prompt lunghi, acceptance rate spec nei log.
- Documentare tutto in `benches/rx9060xt/` nel fork (script build/bench + risultati).
- Rollback pronto: binario vecchio + `preset.ini.bak`.

## Criteri di successo
- Bilanciato pp/tg: nessuna regressione e guadagno complessivo ≥10% (media pp512/2048/8192 + tg128) vs setup attuale.
- TTFT multi-turn migliorato dal riuso prompt (se attivato), RAM entro i limiti dei 32GB.
- 3 modelli stabili a 128k/160k senza OOM; fork con patch isolate (se presenti) + preset aggiornato + bench documentati.

## File toccati
- `~/.config/llama.cpp/preset.ini` (+backup)
- `~/.local/bin/{llama,llama-bench}` (+backup vecchio)
- fork: `benches/rx9060xt/` (script+risultati), eventuali patch isolate
- (opzionale) unit systemd user per `llama serve`

## Rischi
- Build HIP pesante (template): ccache + `-j10`; non disturbare il server attivo.
- `HSA_OVERRIDE`: rimuovere solo dopo verifica rocminfo (se resta, innocua).
- I 12.1GB del math non coesistono in VRAM con nessun altro target.
