# spec test: hip / math / mtp-128k-nkvo

- extra args: `--device ROCm0 -c 128000 --no-kv-offload --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 --cache-type-k-draft q4_0 --cache-type-v-draft q4_0`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 44.5 | 219.0 | 6.1 | 222 | 120 | 54.1% |
| 1 | 37.9 | 221.2 | 7.7 | 226 | 137 | 60.6% |
| 2 | 19.9 | 221.6 | 28.0 | 313 | 180 | 57.5% |

**media (run 1-2, esclusa warmup)**: pred 17.8 t/s, accept 317/539 = 58.8%
