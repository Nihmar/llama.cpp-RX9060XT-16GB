# RX 9060 XT 16GB - risultati benchmark

Log cumulativo delle misurazioni. Ogni blocco riporta commit, configurazione di build,
variabili d'ambiente e parametri di test. I file grezzi di `llama-bench` sono in
`benches/rx9060xt/results/`.

## Ambiente

| voce | valore |
|---|---|
| GPU | AMD Radeon RX 9060 XT 16GB, gfx1200 (Navi 44), 16304 MiB VRAM |
| CPU | Intel Core i5-13400F (6P+4E, 16 thread) |
| RAM | 32 GiB |
| Kernel | (vedi `uname -r`) |
| ROCm | 7.2.4 in `/opt/rocm`, LLVM 22 (`/opt/rocm/lib/llvm/bin/clang`) |
| Vulkan | Mesa RADV (loader 1.4.357), glslc distro |
| Env globali | `LLAMA_CACHE=/home/alessandro/mnt/speed/models`, `ROCM_PATH=/opt/rocm`, `HSA_OVERRIDE_GFX_VERSION=12.0.0` |

Note:
- `HSA_OVERRIDE_GFX_VERSION=12.0.0` e' un no-op: l'arch nativa e' gfx1200 (verificato con
  `rocminfo` con e senza la variabile).
- Modelli via `LLAMA_CACHE`: math = `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S` (11.28 GiB),
  g12 = `unsloth/gemma-4-12B-it-qat-GGUF:UD-Q4_K_XL` (6.24 GiB),
  g4 = `unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL` (3.91 GiB).

## Build

Commit: `6c7a87f7e` (upstream, master) - branch di lavoro `rx9060xt`.

| build dir | backend | flag principali |
|---|---|---|
| `build-hip` | ROCm/HIP | `-DGGML_HIP=ON -DGPU_TARGETS=gfx1200 -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang -DGGML_CUDA_FA_QUANTS=f16-f16;q4_0-q4_0;q8_0-q8_0;bf16-bf16;q8_0-q4_0` |
| `build-vulkan` | Vulkan | `-DGGML_VULKAN=ON` |

Entrambe: `-DCMAKE_BUILD_TYPE=Release`, Ninja, ccache su C/CXX/HIP.

Ricomando la build: `benches/rx9060xt/build.sh hip` oppure `... vulkan`.

## Riepilogo (base: -p 512/2048/8192 -n 128, FA on, -t 12, KV da preset)

| modello | test | HIP t/s | Vulkan t/s | delta (V/H) |
|---|---:|---:|---:|---:|
| math (IQ3_S, ctk q8_0/ctv q4_0) | pp512 | 498.5 | 622.9 | +25% |
| math | pp2048 | 587.0 | 626.4 | +7% |
| math | pp8192 | 590.1 | 586.8 | -1% |
| math | tg128 | 20.04 | 21.77 | +9% |
| g12 (Q4_K_XL, ctk q8_0/ctv q4_0) | pp512 | 1599.7 | 1533.1 | -4% |
| g12 | pp2048 | 1507.0 | 1497.3 | -1% |
| g12 | pp8192 | 1270.0 | 1290.9 | +2% |
| g12 | tg128 | 35.96 | 37.23 | +4% |
| g4 (Q4_K_XL, ctk q4_0/ctv q4_0) | pp512 | 3527.5 | 2557.6 (rumoroso) | -27%* |
| g4 | pp2048 | 3475.7 | 3343.2 | -4% |
| g4 | pp8192 | 2932.5 | 2914.5 | -1% |
| g4 | tg128 | 62.99 | 74.31 | +18% |

\* pp512 Vulkan e' il primo test dopo il load e appare disturbato (pp2048 piu' veloce di
pp512); da ri-misurare su build a cache shader calda.

Prime indicazioni: HIP meglio sul prefill di g4, Vulkan meglio su decode (tutti) e sul
prefill corto di math. Da confermare con la suite `scale` (contesti lunghi).

## Log sessioni

### 2026-09-28 - base HIP (build-hip, commit 6c7a87f7e)
- comando: `ROCM_PATH=/opt/rocm ./benches/rx9060xt/bench-models.sh build-hip hip all base`
- file: `results/hip-all-base-20260928-172706.md`
- dispositivo: `AMD Radeon RX 9060 XT, gfx1200 (0x1200), VMM: no, Wave Size: 32`

### 2026-09-28 - base Vulkan (build-vulkan, commit 6c7a87f7e)
- comando: `./benches/rx9060xt/bench-models.sh build-vulkan vulkan all base`
- file: `results/vulkan-all-base-20260928-173038.md`
- dispositivo: `AMD Radeon RX 9060 XT (RADV GFX1200), warp size: 64, KHR_coopmat`
- nota: prima esecuzione in assoluto del binario Vulkan (cache shader RADV fredda per
  alcune pipeline); i prossimi run Vulkan vanno considerati come riferimento stabile.

### 2026-09-28 - scale HIP (contesti lunghi, in corso)
- comando: `REPS=2 ROCM_PATH=/opt/rocm ./benches/rx9060xt/bench-models.sh build-hip hip <modello> scale`
- copre: prefill fino a 65536 token (math, g12) / 16384 (g4) e decode a profondita' 8192/32768.
- file: `results/hip-<modello>-scale-*.md`

## Convenzioni di tracciamento

- `master` resta identico all'upstream: tutto il lavoro su branch `rx9060xt/*`.
- Un commit (o branch dedicato) per ogni esperimento; nei messaggi di commit le misure
  before/after per le patch di codice.
- Ogni risultato grezzo va in `results/`, e questa tabella viene aggiornata con i numeri.
