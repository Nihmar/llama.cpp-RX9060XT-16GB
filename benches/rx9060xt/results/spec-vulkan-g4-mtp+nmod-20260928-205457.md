# spec test: vulkan / g4 / mtp+nmod

- extra args: `--spec-type draft-mtp,ngram-mod --spec-draft-n-max 2 -md /home/alessandro/mnt/speed/models/models--unsloth--gemma-4-E4B-it-qat-GGUF/snapshots/8c5a9e4fd5482e2be20fe0bf013b4c262a8f4265/mtp-gemma-4-E4B-it.gguf`

| run | wall s | prompt t/s | pred t/s | draft_n | accepted | accept rate |
|---|---|---|---|---|---|---|
| 0 | 2.7 | 2460.8 | 109.3 | 240 | 88 | 36.7% |
| 1 | 2.0 | 2969.6 | 180.6 | 250 | 118 | 47.2% |
| 2 | 1.8 | 2967.2 | 244.1 | 172 | 122 | 70.9% |

**media (run 1-2, esclusa warmup)**: pred 212.3 t/s, accept 240/422 = 56.9%
