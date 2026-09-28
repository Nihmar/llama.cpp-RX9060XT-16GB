# llama-bench: vulkan / math / suite=scale

- data: 2026-09-28 18:26:20
- binario: `build-vulkan/bin/llama-bench`
- suite: `scale`

## math scale (-p 512,8192,32768,65536 -d 8192,32768 -n 128)
```
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon RX 9060 XT (RADV GFX1200) (radv) | uma: 0 | fp16: dot2 | bf16: 1 | fp4: 0 | warp size: 64 | shared memory: 65536 | int dot: 1 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl | threads | type_k | type_v |  fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ------: | -----: | -----: | --: | --------------: | -------------------: |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 |   pp512 @ d8192 |       473.52 ± 20.44 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 |  pp8192 @ d8192 |        501.11 ± 0.29 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 | pp32768 @ d8192 |        414.52 ± 0.07 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 | pp65536 @ d8192 |        334.85 ± 0.04 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 |   tg128 @ d8192 |         21.40 ± 0.02 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 |  pp512 @ d32768 |       344.53 ± 26.39 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 | pp8192 @ d32768 |        352.53 ± 0.21 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 | pp32768 @ d32768 |        303.73 ± 1.59 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 | pp65536 @ d32768 |        188.44 ± 0.06 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | Vulkan     |  99 |      12 |   q8_0 |   q4_0 |   1 |  tg128 @ d32768 |         20.24 ± 0.01 |

build: 6c7a87f7e (11235)
```

