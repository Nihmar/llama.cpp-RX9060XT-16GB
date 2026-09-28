# spec test: vulkan / g12 / nmod-tuned

- extra args: `--spec-type ngram-mod --spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 5.1 | 1199.2 | 84.2 | 121 | 121 | 100.0% |
| 1 | 6.0 | 1299.9 | 56.4 | 98 | 83 | 84.7% |
| 2 | 3.8 | 1299.1 | 165.6 | 162 | 162 | 100.0% |

**media (run 1-2, esclusa warmup)**: pred 111.0 t/s, accept 245/260 = 94.2%
