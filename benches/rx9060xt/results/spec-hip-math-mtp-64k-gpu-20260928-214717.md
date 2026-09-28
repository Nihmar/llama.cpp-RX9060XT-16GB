# spec test: hip / math / mtp-64k-gpu

- extra args: `--device ROCm0 -c 65536 --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 --cache-type-k-draft q4_0 --cache-type-v-draft q4_0`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 11.9 | 511.2 | 30.6 | 232 | 120 | 51.7% |
| 1 | 7.8 | 532.5 | 81.7 | 215 | 174 | 80.9% |
| 2 | 7.7 | 531.3 | 84.0 | 213 | 175 | 82.2% |

**media (run 1-2, esclusa warmup)**: pred 82.9 t/s, accept 349/428 = 81.5%
