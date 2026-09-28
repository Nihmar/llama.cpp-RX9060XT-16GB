# A/B lemonade (TheRock, Clang 24) - math base

```
| model                          |       size |     params | backend    | ngl | threads | type_k | type_v |  fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ------: | -----: | -----: | --: | --------------: | -------------------: |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |           pp512 |       568.73 ± 24.63 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |          pp2048 |        631.95 ± 0.24 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |          pp8192 |        624.34 ± 0.13 |
| qwen35 27B IQ3_S - 3.4375 bpw  |  11.28 GiB |    27.32 B | ROCm       |  99 |      12 |   q8_0 |   q4_0 |   1 |           tg128 |         19.94 ± 0.02 |

build: a97cce8 (1)
```
