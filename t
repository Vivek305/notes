# Advisor note #16: E5 R2 is valid, but the Tier-2 gate is unread. Code to read it is ready

**Date:** 2026-10-14 · **Phase:** Tier 1 closeout → Tier 2 gate
**Reviews:** `602d70a` ("Publish aggregate E5 R2 results", `docs/tier1/2026-10-14_e5_r2_aggregate_results.md`)
**Builds on:** #14 (E5 spec and §5 gate), #15 (R1 review and rerun spec), #13 (Tier-1 closeout), #12 (Tier-2 plan)

**Verdict.**
- **R2 is valid.** The teacher is the 31B (4,338 of 4,341 valid; 3 length stops, 0.07%), the student
  ran on P-split-B, and the outputs match their run-record hashes. R1's 19% truncation is gone, which
  confirms it came from the wrong model. The whitespace remedy is not needed.
- **Fidelity carries over to external text.** Head micro F1 0.956 (T1.5 in-domain: 0.954–0.958),
  abnormal recall 0.997. All 12 paired student − teacher presence intervals on the clean categories
  include 0 or touch it (MIMIC cardiomegaly: upper bound 0.000). That is the paper sentence.
- **Tier 2 is not yet cleared.** #14 §5 decides on location and left/right flips, not presence. The
  scorer computed those, but the readout omits them. Consolidation also trips the >10pp rule.
- **Not a Tier-2 go today.** It becomes a go when the §5 location reading is `clear` or `caveat` and
  #13's closeout items 7–8 are done. Mammography generation can start once its taxonomy exists.

---

## 1. Findings on the R2 readout

| # | Finding | Severity |
|---|---|---|
| 1 | The gate numbers are missing. #14 §5 reads clean-category MIMIC location F1 (limited vocabulary) and the flip rate; binary severity goes beside them. `scores.md` on the server has per-category values but no pooled gate number, and the readout shows presence only | **P0: blocks the Tier-2 decision** |
| 2 | §5 was never recorded in DECISIONS (last entry D54), so the gate is not on record ahead of the readout. Now **D55**, with an honesty note | P0 (fixed in this commit; copilot adds one sentence, step C1) |
| 3 | Consolidation teacher presence: MIMIC 0.717, NIH 0.750, against MAPLEZ's 0.952. That is >10pp, which triggers §5's disagreement breakdown. My guess is a definitional mismatch (v3's narrow `Consolidation (Pneumonia)` vs MAPLEZ's broader category, with the teacher using opacity or atelectasis labels instead). The breakdown has to show it, not us assume it | P1 |
| 4 | The readout leaves out per-cell n, gold positives, the excluded `-1/-3` counts and the invalid-as-negative sensitivity numbers (#14 §6, #15 §5.1) | P1 |
| 5 | All-label macro F1 0.784, CI 0.772–0.852. The point estimate sits at the bottom edge. `scoring.macro_f1` skips labels with no support in the rows scored, so rare labels drop out of bootstrap resamples and the macro rises. The interval is biased upward | P1 (fixed: new `M2_macro_f1_support_ge_10`) |
| 6 | "Externally expected T1.2 and T1.5 hash values were not supplied." The check doesn't need us to supply them; it needs T1.2's and T1.5's own rendered prompts, which are on the server. **The student half is verified here:** E5's student system prompt SHA-256 `bef8491d…` equals the frozen P-split-B corpus hash in `manifests/phase1_corpus.json` (now a test). The teacher half needs step C2 | P1 |
| 7 | MIMIC n = 214 of 350. Prepare has a PhysioNet fallback, but it was not used | P1 |
| 8 | **Advisor bug in `d9a2081`:** that fallback fed the *whole raw report* (indication, history, comparison) to the models. Every ingested MIMIC row is v3's `combined_clean`, FINDINGS + IMPRESSION only. Had the 136 been recovered that way, they would have had different input text. Fixed: the fallback now runs v3's own tier-1/2 section parser and counts the rows v3 would have escalated to its LLM parser | P1 (fixed; R2 unaffected because it recovered 0 rows) |
| 9 | `90cb58c` (the leaked MAPLEZ gold, MIMIC evidence spans and QMS documents) is still reachable on the remote branch. The repo is private now, but the history rewrite (#15 §1) is still the owner's job | P0 owner |

---

## 2. What this commit changes (copilot just runs it)

All of it is tested on synthetic data (140 passed, 15 skipped; the one failure is the known
server-only `prompt.md` test). The scorer also ran end to end on a synthetic run directory.

| File | Change |
|---|---|
| `scripts/tier1_external_score.py` | **Gate.** Pooled location F1 (limited) over effusion, pneumothorax and consolidation; pooled binary severity over those three plus cardiomegaly; flips as `k/n = %`; and `gate_reading` applies D55's thresholds mechanically (`clear` / `caveat` / `stop` / `undetermined`) for teacher and student. **Presence flags:** >10pp below MAPLEZ NIH, and paired Δ within ±2pp with CI ∋ 0. **Disagreements:** for each clean category, the mapped-label status on misses (Uncertain / Absent / not emitted), the other v3 labels asserted on misses, the gold code on false positives (explicit 0 vs not mentioned), and the other gold categories on those rows. Label names and counts only; unlisted findings are counted, never named. `scores.md` now opens with the gate table and carries n, gold+, excluded, invalid and invalid-as-negative in every row. No NaN in the JSON |
| `scripts/tier1_external_eval.py` | `--run-name` (separate run namespace). `generate --reuse-from <run>` takes over an earlier run's rows when the contract is identical and the rendered prompt is byte-identical, so the MIMIC top-up generates about 136 rows, not 4,477. Provenance goes in `run.json`. `prompt-check` proves a model's system prompt appears verbatim in an earlier run's rendered prompts. The PhysioNet fallback uses v3's `combined_clean` (finding 8) and records `from_physionet_v3_would_escalate` |
| `src/radx/v3bridge.py` | `combined_clean_text(raw)`: v3's tier-1/2 section parse, returning `(text, needs_llm)` |
| `scripts/score_v2.py` | Adds `M2_macro_f1_support_ge_10` (label set fixed once, to labels with ≥10 reference positives) and its CI. The old M2 is unchanged, so earlier numbers stay comparable |
| `scripts/build_tier1_freeze.py` (new) | Writes `manifests/v2_tier1_freeze.json` like `v1_freeze.json`. Frozen adapter = `t1_4_s17` by rule, `t1_4_s23` replicate. Every glob must match or it refuses. `--e5-run-dir` checks that E5's student used the frozen adapter fingerprint |
| `gpufleet-e5-r3-mimic350.yml` (new) | R3: prepare with PhysioNet + both prompt pins, generate with `--reuse-from e5_external_eval_r2`, score, fidelity |
| `docs/DECISIONS.md` | **D55**: the E5 gate, thresholds unchanged from #14, recorded after R2 with an honesty note |
| `tests/` | 9 new tests: gate edges, pooling and patient clustering, disagreement privacy, presence flags, reuse (only byte-identical rows reused; resubmission keeps provenance; a different contract is refused), prompt-check (whitespace-trimmed template passes, a one-character change fails), student prompt = frozen P-split-B corpus hash, support-filtered M2 |

---

## 3. Next steps

Run everything from the repo root on the server after `git pull`, with
`PY=.venv/bin/python; export PYTHONPATH=src`. **(verify)** marks paths I can't see from the mirror.

### CPU, today (no GPU, minutes each)

**C1. Read the gate on R2 (n = 214).**

First add one sentence to D55's honesty note: had anyone looked at the location columns of R2's
`scores.md` before this commit? (yes / no). Then:

```bash
$PY scripts/tier1_external_score.py --run-dir data/runs/e5_external_eval_r2 \
    --out data/results/e5_external_eval_r2/scores_v16.json
$PY scripts/score_v2.py --id-column external_id \
    --reference data/predictions/e5_external_eval_r2/teacher.parquet \
    --prediction data/predictions/e5_external_eval_r2/student.parquet \
    --head-labels configs/locked/head_labels.yaml \
    --reports data/runs/e5_external_eval_r2/inputs.parquet --patient-column patient_id \
    --out data/results/e5_external_eval_r2/student_vs_teacher_v16.json
```

Expected: the first table of `scores_v16.md` is the gate, with a reading for teacher and student.
The presence numbers must equal the R2 readout's exactly; nothing else in the scoring changed.
If any presence cell moves, stop and report it.

**C2. Prompt byte-identity.**

```bash
# teacher vs T1.2: any parquet holding T1.2's chat-templated teacher prompts  (verify path + column)
$PY scripts/tier1_external_eval.py --run-name e5_external_eval_r2 prompt-check --model teacher \
    --reference data/runs/t1_2/<t1_2 prompts>.parquet --column <rendered prompt column>
# student vs T1.5: the Tier-1 P-split-B test corpus T1.5 scored  (verify path)
$PY scripts/tier1_external_eval.py --run-name e5_external_eval_r2 prompt-check --model student \
    --reference <tier-1 P-split-B test corpus>.parquet --column prompt_text
```

Each must print `"byte_identical": true`. If T1.2 kept no rendered prompts, give its run record's
system-prompt hash instead; it must equal `f62e1c24341877f72ece5a99d3213d06c82017ae4c5056731be928341ca40b3a`.

**C3. Fetch the 136 MIMIC reports** (credentialed PhysioNet account, under the existing DUA):

```bash
mkdir -p data/external/mimic-cxr-reports && cd data/external/mimic-cxr-reports
wget --user <physionet user> --ask-password \
    https://physionet.org/files/mimic-cxr/2.0.0/mimic-cxr-reports.zip   # the version your DUA lists
unzip -q mimic-cxr-reports.zip && ls files | head   # expect p10 … p19
cd -
```

It stays under `data/`. If the DUA or network rules this out, record **D56: MAPLEZ-MIMIC
n = 214 accepted** (with the reason) and skip G1.

**C4. Publish the E5 readout v2.**

Replace or extend `docs/tier1/2026-10-14_e5_r2_aggregate_results.md` with:
- the gate table and its reading;
- the full presence table (n, gold+, excluded, invalid, invalid-as-negative);
- the location/severity table per dataset;
- the presence flags;
- the consolidation disagreement summary;
- M2 support ≥ 10 with its CI, plus the M2 caveat;
- the C2 result.

Rules: aggregates only, and wording per #14 §6 ("agreement with MAPLEZ human annotations", never
"accuracy"). If G1 runs, the gate is read on n = 350, with n = 214 beside it.

**C5. Tier-1 closeout status.** Send one line per #13 item 1–9: done (path or commit) / not done.
The mirror shows **no** `manifests/v2_tier1_freeze.json`, **no** DECISIONS entries after D54 for
#13 §4's four decisions, **no** `docs/tier1/results_tier_1.md`, and no `3.45k-nt` / T1.3 s23
config or result. If those exist on the server, push the aggregates.

**C6. Freeze manifest** (only after the #13 §4 decisions are recorded):

```bash
$PY scripts/build_tier1_freeze.py \
    --corpus '<t1_3 corpus glob>' --corpus '<t1_4 corpus glob>' \
    --eval-report 'reports/eval/t1_5_*' \
    --e5-run-dir data/runs/e5_external_eval_r2        # (verify globs)
```

Commit `manifests/v2_tier1_freeze.json`. It holds paths and hashes only.

### GPU

| # | Job | Needs first | Size | Reads against |
|---|---|---|---|---|
| **G1** | `gpufleet-e5-r3-mimic350.yml`: E5 on the 350 MAPLEZ-MIMIC studies, reusing R2 rows | C2 pass, C3 | 1 GPU, about 20–30 min (mostly 31B load); `max_train_hrs: 1` | `prepare` prints `unavailable_rows: 0` (or what PhysioNet lacks); each `generate` prints `rows_left` ≈ 136. Then C1/C4 on `e5_external_eval_r3` |
| G2 | `3.45k-nt` and T1.3 s23 (#13 item 4), **if not already run** | C5 says not done | 2 GPUs × ~10 h | #13 §2–3: M2 decomposition, schema-cost attribution |
| G3 | M10 adversarial suite on `t1_4_s17` (#13, optional) | none | short teacher + student pass | "not measured" otherwise |
| G4 | Tier-2 **generation only**: T2.1a capacity probe → T2.1 teacher (2 shards) → T2.2 zero-shot (#12 §1.3) | `configs/taxonomies/mammography.yaml` and the readings A/B entry in DECISIONS (T2.0). **Neither exists in the mirror** | 15 min; ~1 h on 2 GPUs; ~1 h | #12 gates. Generate now, read only after the Tier-2 gate |
| — | **T2.3 joint training** | §4 below | 2 × ~15 h | — |

### Owner

- **O1.** Rewrite history (#15 §1). Use `git filter-repo` to drop `data/`, `advisor/` and the
  `v3/` non-source files from every branch, then force-push. Until then, nobody fetches this
  remote onto a new machine.
- **O2.** Record #13 §4's four decisions:
  1. one joint adapter;
  2. frozen = `t1_4_s17` by rule;
  3. schema v2 adopt / adopt with recorded costs / narrow, per #13 §4.3's pre-written rule;
  4. production arm P-split-B.
- **O3.** Mammography taxonomy and the readings A/B (T2.0) with the clinician; this unblocks G4.
- **O4.** D56, if C3 is not possible.

---

## 4. Tier-2 joint training (T2.3) starts when all of these hold

1. **E5 gate** (D55) reads `clear` or `caveat` on MAPLEZ-MIMIC, at n = 350 if G1 ran. If it reads
   `stop`, Tier 2 does not train on location. The owner picks between a location re-label and
   dropping location from the loss.
2. If the consolidation breakdown shows the gap is a teacher error rather than a definition
   difference, the owner records how Tier 2 handles it.
3. #13 items 7 and 8 are done: the four decisions are recorded and the freeze manifest is committed.
   Items 2–6 are reported as done or explicitly deferred.
4. T2.1 has passed its merge gate and T2.2 has been scored (#12 §1.3).

Expected path if nothing surprises: C1–C4 today, G1 tomorrow morning, the gate read the same day.
Closeout (O2, C6) and T2.0 decide the actual start date of T2.3, not E5.

## 5. What to send back

1. The C1 gate table (teacher and student) and the presence-equality check. If G1 has run, both n.
2. The C2 results, as two JSON lines.
3. The consolidation disagreement summary for teacher and student, counts only.
4. C5's 9-line closeout status, and the status of O1–O3, including "not started" where that's true.
