# llama-bench: hip-gdn / math / suite=scale

- data: 2026-09-28 19:58:07
- binario: `build-hip-gdn/bin/llama-bench`
- suite: `scale`

## math scale (-p 512,8192,32768,65536 -d 8192,32768 -n 128)
```
ggml_cuda_init: found 1 ROCm devices (Total VRAM: 16304 MiB):
  Device 0: AMD Radeon RX 9060 XT, gfx1200 (0x1200), VMM: no, Wave Size: 32, VRAM: 16304 MiB
| model                          |       size |     params | backend    | ngl | threads | type_k | type_v |  fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ------: | -----: | -----: | --: | --------------: | -------------------: |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |   pp512 @ d8192 |        550.45 ± 5.82 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |  pp8192 @ d8192 |        548.18 ± 0.16 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 | pp32768 @ d8192 |        490.64 ± 0.14 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 | pp65536 @ d8192 |        430.71 ± 0.00 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |   tg128 @ d8192 |         18.98 ± 0.02 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |  pp512 @ d32768 |       432.89 ± 18.32 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 | pp8192 @ d32768 |        443.04 ± 0.09 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 | pp32768 @ d32768 |        405.70 ± 0.05 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 | pp65536 @ d32768 |        358.48 ± 8.11 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |  tg128 @ d32768 |         15.57 ± 0.03 |

build: de3199c06 (11244)
```

