# spec test: hip / math / mtp+nmod

- extra args: `--spec-type draft-mtp,ngram-mod --spec-draft-n-max 2`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 11.4 | 527.3 | 32.4 | 230 | 121 | 52.6% |
| 1 | 7.4 | 552.6 | 89.2 | 212 | 175 | 82.5% |
| 2 | 7.4 | 552.2 | 88.8 | 212 | 175 | 82.5% |

**media (run 1-2, esclusa warmup)**: pred 89.0 t/s, accept 350/424 = 82.5%
