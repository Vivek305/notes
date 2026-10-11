# T1.2 and W0-2 Guided T=0.1 Readout

**Date:** 2026-10-11
**Status:** completed aggregate readout; no patient text or row-level output is included.

## Artifacts

| Artifact | Location | Result |
|---|---|---|
| T1.2 aggregate | `reports/eval/t1_2_teacher_v2.{json,md}` | Four-shard merge completed in the H1004 debug container. |
| T1.2 target table | `data/predictions/t1_2_teacher_v2/teacher_targets.parquet` | 72,734 deterministic v2 no-trace student targets. |
| W0-2 guided T=0.1 | `reports/eval/w0_2_guided_t01_schema_v2.{json,md}` | Completed on the nested 1,000-report cohort. |
| Guided self-agreement | `reports/eval/w0_2_guided_schema_v2_self_agreement.{json,md}` | Compares frozen T1.2 T=0 output with W0-2 T=0.1. |

## T1.2 contract and merge verification

- Teacher: `google/gemma-4-31B-it`; schema v2; reasoning trace present for generation; guided JSON; temperature 0; cap 2,048; model length 10,240; GPU reservation target 0.97; prefix caching enabled.
- Cohort: 72,734 reports with manifest SHA-256 `a22a48f340bced48cd974cde2b6e279b030cd3b05113445050ddac3925e61f14`.
- The four SHA-256 report-ID shards contained 18,325, 18,158, 18,095, and 18,156 reports, respectively.
- Merge invariants passed: every manifest report appeared exactly once, all four shards were present, no duplicate report IDs occurred, and invalid or at-cap rows were retained rather than regenerated.
- The materialized student targets are deterministic schema-v2 serializations with no reasoning trace.

## T1.2 aggregate generation results

| Measure | Value |
|---|---:|
| Reports | 72,734 |
| JSON validity | 99.615% |
| Rows at cap | 280 (0.385%) |
| Invalid rows not at cap | 0 |
| Truncation repairs | 1 |
| Mean findings/report | 3.6763 |
| Mean explicit absent findings/report | 1.6591 |
| Location populated | 52.981% |
| Severity populated | 32.106% |
| Probability populated | 100.000% |
| Output tokens, mean / p95 / p99 / max | 358.2 / 694 / 955 / 2,048 |

### Role-level results

| Role | Reports | JSON validity | At cap | Findings/report | Tokens mean / p95 |
|---|---:|---:|---:|---:|---:|
| anatomy_abdomen | 523 | 100.000% | 0 | 3.0038 | 311.79 / 510 |
| anatomy_extremity | 7,019 | 99.843% | 11 | 2.2559 | 267.09 / 486 |
| anatomy_ribs | 456 | 100.000% | 0 | 2.4386 | 264.96 / 507 |
| anatomy_spine | 5,093 | 99.686% | 16 | 3.4388 | 366.62 / 635 |
| chest_test_internal | 3,248 | 99.661% | 11 | 2.5317 | 273.48 / 504 |
| chest_test_prod | 11,395 | 99.561% | 50 | 4.2193 | 393.24 / 731 |
| chest_train | 45,000 | 99.573% | 192 | 3.8902 | 370.18 / 718 |

### Per-shard execution and telemetry

| Shard | Reports | Wall time | Reports/s | At cap | Peak GPU reservation |
|---|---:|---:|---:|---:|---:|
| 0 | 18,325 | 12,750.8 s | 1.437 | 75 | 80,295 MiB |
| 1 | 18,158 | 12,334.6 s | 1.472 | 68 | 80,295 MiB |
| 2 | 18,095 | 12,402.4 s | 1.459 | 72 | 80,295 MiB |
| 3 | 18,156 | 12,428.0 s | 1.461 | 65 | 80,295 MiB |

The total of per-shard wall time is 49,915.8 s. Every shard telemetry capture reports 14,672 KV-cache tokens, estimated maximum concurrency 1.43, and zero preemption warnings. The 80,295 MiB figure is the vLLM process reservation sampled by `nvidia-smi`, not workload working-set memory. This vLLM build did not emit prefix-cache hit rate or KV-cache usage percentage.

## Fidelity to the v3 teacher reference

On the 59,643 chest reports, asserted-label agreement between v1 and v2, treating invalid v2 output as an empty label set, was:

| Scope | Micro F1 |
|---|---:|
| All chest labels | 0.953865 |
| Head labels | 0.956568 |

This is a v1-to-v2 reference comparison and is useful for tracking fidelity to the v3 teacher; it is not a clinical-performance estimate.

## W0-2 guided T=0.1 control

The completed control used the precommitted 1,000-report cohort nested in T1.2 (`w0_2_trace`), with the same traced, guided schema-v2 contract as T1.2 except temperature 0.1.

| Measure | Value |
|---|---:|
| Reports | 1,000 |
| Wall time / reports per second | 616.6 s / 1.622 |
| JSON validity | 99.200% |
| Rows at cap | 8 (0.800%) |
| Invalid rows not at cap | 0 |
| Mean output tokens / p95 / max | 382.6 / 734 / 2,048 |
| Asserted-label micro F1 vs v1, invalid as empty | 0.955798 |
| Asserted-label micro F1 vs v1, valid rows only | 0.960208 |
| Peak GPU reservation | 80,299 MiB |
| Preemption warnings | 0 |

The frozen T1.2 T=0 outputs and the new T=0.1 outputs have 991 valid pairs and asserted-label micro F1 0.984606. This is the guided self-agreement reference for the later T1.3 temperature comparison.

## Immediate follow-through

1. Preserve the T1.2 aggregate and target table as the frozen corpus reference for dependent work.
2. Use the recorded guided self-agreement result when interpreting the T1.3 temperature experiment.
3. Continue the handoff sequence with T1.3 and T1.4, which can now consume the completed T1.2 corpus and aggregate diagnostics.
