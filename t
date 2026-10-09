# Wave 0 schema-v2 execution log

**Date:** 2026-10-09  
**Scope:** aggregate-only log of W0-1a, W0-1b, W0-1c, and W0-2. No report text,
identifiers, prompts, or generations appear here.  
**Status:** all four scheduled Wave-0 jobs completed.

## Job contract and implementation

Wave 0 is recorded in `docs/DECISIONS.md` D50. The runner is
`scripts/w0_schema_v2.py`; it writes prompts, cohorts, generations, vLLM logs, and
per-job telemetry only under `data/{runs,predictions}/w0_*`. It emits aggregate JSON
and Markdown reports under `reports/eval/`. For each output, it records model settings,
wall time, throughput, `finish_reason`, output-token distribution, parser method,
repair count, invalid-at-cap versus invalid-not-at-cap counts, asserted-label micro-F1
versus canonical v1 assertions, and per-label aggregate F1.

W0-1a and W0-1b use vLLM without structured JSON output. W0-1c uses the Pydantic
schema emitted by `radx.schema_v2.output_json_schema()` through vLLM structured output.
The parser accepts v3 direct parses and its repair/extraction paths; this log reports
the observed method counts rather than treating any method as equivalent by assumption.

## Completed adverse 256-row jobs

| Job | Teacher contract | JSON decoding | Cap / context | At cap | JSON validity | Asserted-label micro-F1, empty / valid only | Finish reasons |
|---|---|---|---:|---:|---:|---:|---|
| W0-1a | trace retained | unguided | 2,048 / 10,240 | 0/256 | 0.980469 | 0.920763 / 0.931354 | 256 stop |
| W0-1b | no trace | unguided | 1,024 / 9,216 | 10/256 | 0.976562 | 0.916092 / 0.934074 | 246 stop; 10 length |
| W0-1c | trace retained | guided JSON schema | 2,048 / 10,240 | 1/256 | 0.996094 | 0.939099 / 0.941814 | 255 stop; 1 length |

## Format and truncation diagnostics

| Job | Finish reasons | Parse methods | JSON-invalid rows: at cap / not at cap | Repairs | Output tokens mean / p95 / max |
|---|---|---|---:|---:|---:|
| W0-1a | 256 stop | 256 extracted-from-prose | 0 / 5 | 256 | 733.47 / 1,112 / 2,032 |
| W0-1b | 246 stop, 10 length | 253 extracted-from-prose, 3 failed | 3 / 3 | 253 | 611.70 / 945 / 1,022 |
| W0-1c | 255 stop, 1 length | 255 direct-parse, 1 failed | 1 / 0 | 0 | 752.58 / 1,131 / 2,047 |

The `nvidia-smi` sampler recorded peak use of 80,235 MiB for W0-1a and W0-1b and
80,289 MiB for W0-1c. The runner labels this as vLLM process-reservation telemetry.
The log extractor recorded 14,670–14,672 KV-cache tokens, maximum concurrency of
1.43–1.59, no emitted cache-usage percentage, and zero preemption-warning matches.

## W0-2 fixed random 1,000-row cohort

The first W0-2 attempt stopped before cohort preparation because its selector passed a
string SHA-256 rank to `DataFrame.nsmallest()`. The runner now uses stable lexical
sorting of that same rank. The completed resubmission used the fixed seeded random
1,000-row cohort for all three sub-runs.

| Job | Teacher contract | Temperature | JSON decoding | Cap / context | At cap | JSON validity | Asserted-label micro-F1, empty / valid only | Finish reasons |
|---|---|---:|---|---:|---:|---:|---:|---|
| W0-2 trace | trace retained | 0.0 | unguided | 2,048 / 10,240 | 1/1,000 | 0.996000 | 0.948947 / 0.956117 | 999 stop; 1 length |
| W0-2 no-trace | no trace | 0.0 | unguided | 1,024 / 9,216 | 4/1,000 | 0.997000 | 0.939794 / 0.945213 | 996 stop; 4 length |
| W0-2 trace T=0.1 | trace retained | 0.1 | unguided | 2,048 / 10,240 | 0/1,000 | 0.995000 | 0.947824 / 0.954981 | 1,000 stop |

| Job | Parse methods | JSON-invalid rows: at cap / not at cap | Repairs | Output tokens mean / p95 / max | Wall time / reports per second |
|---|---|---:|---:|---:|---:|
| W0-2 trace | 1,000 extracted-from-prose | 0 / 4 | 1,000 | 366.74 / 707 / 2,046 | 572.5 s / 1.747 |
| W0-2 no-trace | 999 extracted-from-prose, 1 failed | 1 / 2 | 999 | 287.43 / 592 / 1,022 | 416.7 s / 2.400 |
| W0-2 trace T=0.1 | 1,000 extracted-from-prose | 0 / 5 | 1,000 | 365.82 / 701 / 1,298 | 581.8 s / 1.719 |

The three W0-2 sampler peaks were 80,235 MiB. The log extractor recorded 14,670
KV-cache tokens and maximum concurrency 1.59 for W0-2 no-trace, and 14,672 tokens and
1.43 for each traced run. No cache-usage percentage was emitted, and no preemption
warnings matched in any W0-2 log.

The W0-2 YAML executes:

1. traced teacher at temperature 0 on the fixed random 1,000;
2. no-trace teacher at temperature 0 on the same 1,000;
3. traced teacher at temperature 0.1 on the same 1,000, followed by the v2
   self-agreement report.

The self-agreement report aligns W0-2 trace and W0-2 trace T=0.1. It records 1,000
reports, 994 valid pairs, and asserted-label micro-F1 of 0.983549.

The source aggregates are [W0-1a](../reports/eval/w0_1a_schema_v2_trace.md),
[W0-1b](../reports/eval/w0_1b_schema_v2_no_trace.md), and
[W0-1c](../reports/eval/w0_1c_schema_v2_guided.md),
[W0-2 trace](../reports/eval/w0_2_trace_schema_v2.md),
[W0-2 no-trace](../reports/eval/w0_2_no_trace_schema_v2.md),
[W0-2 trace T=0.1](../reports/eval/w0_2_trace_t01_schema_v2.md), and
[W0-2 self-agreement](../reports/eval/w0_2_schema_v2_self_agreement.md).
