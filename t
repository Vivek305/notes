# Tier 1 Wave-2 training completion — advisor review

**Date:** 2026-10-12  
**Scope:** T1.3 chest-only schema-v2 student, T1.4 joint schema-v2 student (seeds 17 and 23),
and T1.5 unguided evaluation.  
**Data handling:** Aggregate-only. No report text, report IDs, prompts, generations, or row-level predictions are included.

## Executive readout

All three planned training runs completed and wrote adapters plus `run.json` provenance under
`data/runs/`. They used the prepared no-trace schema-v2 corpora and the pre-registered
two-epoch, effective-batch-64 recipe. T1.5 job 48753 also completed: it generated and
aggregate-scored every planned adapter-by-scope pair with unguided decoding.

| Job | Final job ID | Result | Seed | Corpus rows | Steps | Runtime | s/step | Peak training VRAM |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| T1.3 chest-only v2 | 48722 | completed | 17 | 44,808 | 1,401 | 9h 32m 40s | 24.53 | 58.10 GiB |
| T1.4 joint v2 | 48725 | completed | 17 | 54,182 | 1,694 | 11h 47m 56s | 25.07 | 58.10 GiB |
| T1.4 joint v2 | 48726 | completed | 23 | 54,182 | 1,694 | 11h 52m 08s | 25.22 | 58.06 GiB |

The completed runs are 4.2%–6.9% faster than the 3.45k reference rate of 26.33 s/step.
The 58.1-GiB peak is the recorded training working set, below the 80-GiB H100 capacity.

On the primary schema-v2 chest comparisons, T1.3 reached head-label fidelity to the v3 teacher
of 0.9568 (internal) and 0.9540 (production). T1.4 seed 17 reached 0.9566 and 0.9546; seed 23
reached 0.9581 and 0.9542. All unguided JSON-validity values exceeded the 0.99 fallback
threshold, so guided decoding was not used. The two joint seeds remain within 0.0013 of T1.3 on
chest M1, well inside the pre-registered 0.01 joint-training tolerance.

## Training contract and provenance

| Run | Corpus SHA-256 | Config SHA-256 | Source SHA-256 | Target | Max sequence | Effective batch | Warmup |
|---|---|---|---|---|---:|---:|---:|
| T1.3 | `e2cdf9246c0d…b318dade` | `d73e2dd9e948…8eaf7a9c` | `944e10bdb772…540bddce` | `target_text_no_trace` | 3,076 | 64 | 42 steps |
| T1.4 s17 | `596cea1f8a39…c7624b95` | `586856345472…c51c053` | `944e10bdb772…540bddce` | `target_text_no_trace` | 3,076 | 64 | 51 steps |
| T1.4 s23 | `596cea1f8a39…c7624b95` | `1ad851a4ebd…ca222d07` | `944e10bdb772…540bddce` | `target_text_no_trace` | 3,076 | 64 | 51 steps |

Each completed run logged 343 LoRA target modules across 10 module kinds, 155.5M trainable
parameters out of 8,096.6M, and `resumed_from_step: 0`. The T1.4 seeds share the exact joint
corpus hash as required.

## Pre-launch corpus gates carried into these runs

- **D54** records the Wave-2 training and scoring contract.
- T1.3 retained 44,808 valid, uncensored, unrepaired chest targets from the frozen 45k
  P-split-B source. The prompt-byte identity and schema-v2 no-trace round-trip checks passed.
- T1.4 retained that exact T1.3 chest component and added audited spine/extremity rows for
  54,182 total rows. The leakage audit removed 137 L1 and 104 L3 prohibited overlaps;
  L2 cross-anatomy test overlap was zero for both directions.
- The measured maximum prompt-plus-target sequence length was 3,076, below the 4,700-token
  training wall.
- The remote preflight passed corpus integrity, tokenizer contract, CUDA, training stack, and
  disk headroom before the launches.

## Operational note

The first T1.4 seed-17 and seed-23 submissions (jobs 48723 and 48724) failed before training
with CUDA error 803, an unsupported display-driver/CUDA-driver combination. Restore submissions
48725 and 48726 started from no checkpoint and completed; this is reflected by
`resumed_from_step: 0` in both final run records. T1.3 completed on its first submission.

## T1.5 unguided evaluation — completed

**Execution.** Job 48753, `cxr-nt-t1-5-schema-v2-evaluation`, completed on 2026-10-12. The
terminal log records all six scopes generated and scored for each adapter; the VLLM `SIGTERM` /
`start mode=abort` messages occur after each adapter's completed requests and are normal engine
teardown. No job abort occurred. All 18 prediction sets had zero missing rows. Scoring used
temperature 0, unguided decoding, and a 2,048-token output cap. M12 was computed with medspaCy.

**Denominators.** The primary v2 chest populations contain 3,237 internal and 11,345 production
reports. The 11 internal and 50 production invalid teacher rows were excluded before the frozen
scoring reference files were written; each scored reference file therefore contains zero invalid
rows. Anatomy populations are 466 abdomen, 1,333 extremity, 428 ribs, and 967 spine reports.
All four exclude the required chest-training patient overlap; spine and extremity additionally
use their frozen anatomy test assignments.

### Primary v2 results

M5 is reported as **Absent / asserted** evidence exact-match rate. Anatomy M1 is shown as N/A:
the scorer currently obtains its head-label list from the immutable chest taxonomy, which has no
labels in common with runtime anatomy taxonomies; its emitted `0.0000` is a denominator artifact,
not a measure of anatomy fidelity to the v3 teacher. M2–M6 and M12 use each runtime taxonomy.

| Adapter | Scope | N | M1 | M2 | M3 | M4 | M5 absent / asserted | M6 | M12 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| T1.3 | abdomen | 466 | N/A | 0.4389 | 0.9728 | 0.8997 | 0.9458 / 0.9792 | 1.0000 | 0.0728 |
| T1.3 | extremity | 1,333 | N/A | 0.3854 | 0.9817 | 0.9777 | 0.9100 / 0.9822 | 0.9940 | 0.1095 |
| T1.3 | ribs | 428 | N/A | 0.3748 | 0.9494 | 0.9642 | 0.9491 / 0.9883 | 0.9977 | 0.0760 |
| T1.3 | spine | 967 | N/A | 0.4217 | 0.9778 | 0.9227 | 0.9643 / 0.9899 | 0.9959 | 0.0608 |
| T1.3 | chest internal | 3,237 | 0.9568 | 0.7948 | 0.9921 | 0.9952 | 0.9566 / 0.9923 | 1.0000 | 0.0026 |
| T1.3 | chest production | 11,345 | 0.9540 | 0.7903 | 0.9966 | 0.9950 | 0.9609 / 0.9328 | 0.9997 | 0.0113 |
| T1.4 s17 | abdomen | 466 | N/A | 0.5357 | 0.9891 | 0.8721 | 0.8967 / 0.9931 | 1.0000 | 0.0675 |
| T1.4 s17 | extremity | 1,333 | N/A | 0.5779 | 0.9897 | 0.9916 | 0.9318 / 0.9746 | 1.0000 | 0.1123 |
| T1.4 s17 | ribs | 428 | N/A | 0.6020 | 0.9831 | 0.9863 | 0.9547 / 0.9934 | 1.0000 | 0.0987 |
| T1.4 s17 | spine | 967 | N/A | 0.6583 | 0.9944 | 0.9825 | 0.9407 / 0.9427 | 1.0000 | 0.0664 |
| T1.4 s17 | chest internal | 3,237 | 0.9566 | 0.7686 | 0.9908 | 0.9934 | 0.9529 / 0.9902 | 1.0000 | 0.0026 |
| T1.4 s17 | chest production | 11,345 | 0.9546 | 0.7941 | 0.9965 | 0.9950 | 0.9626 / 0.9285 | 0.9999 | 0.0112 |
| T1.4 s23 | abdomen | 466 | N/A | 0.6103 | 0.9810 | 0.8884 | 0.9458 / 0.9890 | 1.0000 | 0.0697 |
| T1.4 s23 | extremity | 1,333 | N/A | 0.4968 | 0.9932 | 0.9911 | 0.9319 / 0.9755 | 1.0000 | 0.1118 |
| T1.4 s23 | ribs | 428 | N/A | 0.5920 | 0.9789 | 0.9764 | 0.9546 / 0.9861 | 1.0000 | 0.1042 |
| T1.4 s23 | spine | 967 | N/A | 0.6915 | 0.9956 | 0.9610 | 0.9492 / 0.9443 | 1.0000 | 0.0683 |
| T1.4 s23 | chest internal | 3,237 | 0.9581 | 0.8038 | 0.9928 | 0.9946 | 0.9556 / 0.9916 | 0.9997 | 0.0033 |
| T1.4 s23 | chest production | 11,345 | 0.9542 | 0.7572 | 0.9965 | 0.9957 | 0.9609 / 0.9333 | 0.9998 | 0.0111 |

### Chest diagnostics and comparisons

The location and severity diagnostics below are exact agreement with the v2 teacher followed by
the rate that emitted text appears verbatim in the source. PMAD is the mean absolute probability
difference. Full status-confusion matrices remain in the aggregate-only T1.5 JSON artifacts.

| Adapter | Scope | Location exact / source | Severity exact / source | PMAD |
|---|---|---:|---:|---:|
| T1.3 | internal | 0.8066 / 1.0000 | 0.7860 / 1.0000 | 0.0015 |
| T1.3 | production | 0.8456 / 0.9748 | 0.7667 / 0.9906 | 0.0058 |
| T1.4 s17 | internal | 0.8132 / 0.9993 | 0.7889 / 0.9994 | 0.0014 |
| T1.4 s17 | production | 0.8458 / 0.9744 | 0.7658 / 0.9905 | 0.0060 |
| T1.4 s23 | internal | 0.8225 / 1.0000 | 0.7783 / 1.0000 | 0.0012 |
| T1.4 s23 | production | 0.8464 / 0.9747 | 0.7680 / 0.9904 | 0.0060 |

The retained-denominator 3.45k v1 comparison is descriptive only: it uses the v1 teacher and
the same valid chest rows, whereas the primary results above use the v2 teacher. It measured M1
of 0.9657 internal and 0.9605 production, M2 of 0.8534 and 0.8857, M3 of 0.9941 and 0.9979, M4
of 0.9941 and 0.9938, M5 of 0.9972 and 0.9823, and M6 of 1.0000 and 0.9999, respectively. T1.3's
descriptive M1 difference from that v1 reference is -0.0089 internal and -0.0065 production;
both are within the 0.01 schema-cost guide. A same-scorer guided-v2 self-agreement reference is
not produced by job 48753 and should be included beside this comparison before making a final
schema decision.

### Gate reading

- **Unguided-format gate: passed.** The minimum M6 is 0.9940, so the pre-committed guided-decoding
  fallback did not trigger.
- **Joint-training chest gate: passed for both seeds.** Relative to T1.3, the T1.4 M1 changes are
  -0.0002 / +0.0006 (s17, internal / production) and +0.0013 / +0.0002 (s23), all within 0.01.
- **Anatomy reading: promising but incomplete.** T1.4 generally improves M2 over T1.3, especially
  on spine and ribs, but M1 cannot be interpreted until the scorer is given a runtime-anatomy
  head-label definition or that column is formally removed for anatomy. M12 ranges from 0.0608 to
  0.1123 across anatomy, materially above chest (0.0026–0.0113), and should be reviewed alongside
  the runtime taxonomy and evidence policy before any release claim.
- **Evidence reading: requires advisor review.** Asserted evidence fidelity is high on internal
  chest (0.9902–0.9923) but 0.9285–0.9333 on production chest; location and severity source rates
  are near-extractive, while exact teacher agreement is lower. This is a schema-v2 evidence-format
  question, not evidence of clinical correctness.

Aggregate sources are `reports/eval/t1_5_t1_{3,4_s17,4_s23}_*.{json,md}` and
`reports/eval/t1_5_3_45k_v1_matched_chest_test_{internal,prod}.{json,md}` on the compute
repository. They contain aggregate metrics only; report text, identifiers, prompts, and
generations remain under `data/`.
