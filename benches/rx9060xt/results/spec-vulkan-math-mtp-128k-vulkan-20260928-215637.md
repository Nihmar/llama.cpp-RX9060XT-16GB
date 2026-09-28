# spec test: vulkan / math / mtp-128k-vulkan

- extra args: `--device Vulkan0 -c 128000 --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 --cache-type-k-draft q4_0 --cache-type-v-draft q4_0`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 18.2 | 385.6 | 17.9 | 211 | 119 | 56.4% |
| 1 | 12.2 | 514.8 | 28.9 | 362 | 146 | 40.3% |
| 2 | 9.5 | 524.4 | 48.6 | 339 | 169 | 49.9% |

**media (run 1-2, esclusa warmup)**: pred 38.8 t/s, accept 315/701 = 44.9%
