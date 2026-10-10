# T1.2 CPU preparation log

**Date:** 2026-10-09  
**Scope:** local CPU work following `advisor/wave0-readout-review.md`. This record contains
aggregate metrics and file fingerprints only.

## Completed local work

- Pulled the required W0-1a, W0-1c, and W0-2 trace predictions into local `data/` for
  CPU-only parsing. They remain in `data/`.
- Ran `scripts/t1_2_cpu_preflight.py analyze-wave0`, which wrote
  `reports/eval/t1_2_cpu_preflight.{json,md}`.
- Ran `scripts/t1_2_cpu_preflight.py prepare-manifest`, which wrote the row-level manifest,
  four shard manifests, and anatomy split under `data/runs/t1_2/`, plus
  `reports/eval/t1_2_manifest.{json,md}`.
- Recorded the frozen contract, manifest, evaluation rule, invalid-row handling, and anatomy
  split in `docs/DECISIONS.md` D51.

## P1 — v2 field-population comparison, adverse 256 rows

| Metric | W0-1a unguided trace | W0-1c guided trace | Guided minus unguided |
|---|---:|---:|---:|
| Valid parsed reports | 251 | 255 | 4 |
| Findings per report | 8.105469 | 8.355469 | 0.250000 |
| Explicit Absent per report | 1.718750 | 1.757812 | 0.039062 |
| Location nonempty rate | 0.686747 | 0.667134 | -0.019613 |
| Severity nonempty rate | 0.397590 | 0.400187 | 0.002597 |
| Probability populated rate | 1.000000 | 1.000000 | 0.000000 |

The complete label-level P2 tables are retained in the aggregate JSON report; no report-level
generations were written outside `data/`.

## P2 — label-drift tables

`t1_2_cpu_preflight.json` contains two per-label asserted-F1 mappings:

1. W0-2 trace v2 versus canonical v1 on the fixed random 1,000-row cohort.
2. W0-1c guided trace versus W0-1a unguided trace on their shared adverse 256-row cohort.

The mappings preserve exact emitted label strings, including any spelling or whitespace variation,
so the table records schema-output drift rather than normalizing it away.

## P3 — guided throughput and prefix-cache evidence

W0-1c recorded 434.6 seconds for 256 adverse rows, or 0.589 reports/s. The runner instantiates
vLLM with `enable_prefix_caching=True`. The captured telemetry recorded 14,672 KV-cache tokens,
maximum concurrency 1.43, and zero preemption-warning matches; it does not emit a prefix-cache
hit-rate field. No replacement throughput estimate was generated.

## Frozen T1.2 manifest

| Role | Rows |
|---|---:|
| Exact P-split-B 45k chest training corpus | 45,000 |
| Locked chest test, internal | 3,248 |
| Locked chest test, production | 11,395 |
| Spine | 5,093 |
| Extremity | 7,019 |
| Abdomen, evaluation-only | 523 |
| Ribs, evaluation-only | 456 |
| **Total** | **72,734** |

The four deterministic SHA-256 report-ID shards contain 18,325, 18,158, 18,095, and 18,156 rows.
The row-level manifest hash is
`a22a48f340bced48cd974cde2b6e279b030cd3b05113445050ddac3925e61f14`.

The seeded spine/extremity split is patient-disjoint within each anatomy: spine 4,056 train / 1,037
test and extremity 5,610 train / 1,409 test. Its overlap audit records 126 anatomy-test patients
and 142 anatomy-test reports that also occur among the chest 45k training patients. The manifest
preserves that audit for the T1.4 corpus filter.

The canonical aggregate sources are [CPU preflight](../reports/eval/t1_2_cpu_preflight.md) and
[T1.2 manifest](../reports/eval/t1_2_manifest.md).
