# spec test: vulkan / g12 / mtp+nmod

- extra args: `--spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 -md /home/alessandro/mnt/speed/models/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/980b060c40a8539ac159e0501a3e0f66a6365af3/mtp-gemma-4-12B-it.gguf --spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 6.1 | 1172.1 | 60.2 | 162 | 109 | 67.3% |
| 1 | 4.2 | 1254.0 | 130.0 | 237 | 162 | 68.4% |
| 2 | 4.5 | 1269.3 | 105.0 | 179 | 148 | 82.7% |

**media (run 1-2, esclusa warmup)**: pred 117.5 t/s, accept 310/416 = 74.5%
