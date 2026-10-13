# Advisor plan #12 — next steps: finish Tier 1 cleanly, then mammography (Tier 2) and CT (Tier 3)

**Date:** 2026-10-12 · **Phase:** Tier 1 close → Tier 2 → Tier 3 (feasibility + first experiments)
**Owner input:** mammography and some Tier-3 experiments are required in this window; CT data
(CT-RATE, and PhysioNet access) is expected within a few days.
**Builds on:** #11 (`2026-10-12_tier1_wave2-review_publication-path.md`). #11's P0 list still
applies. This note **revises #11 §4 "hold Tier 2"** as follows: generation work (teacher passes,
zero-shot inference) may start now; **no Tier-2/3 result is read, and no joint training starts,
until the v2 scorer is fixed** (P0 items 1–4, 7). All figures are fidelity to the v3 teacher.

---

## 0. The rule that lets us go faster without losing attribution

**Generate freely, read only through a fixed scorer.** Teacher labeling and student inference don't
depend on the scorer, so they can run in parallel with the P0 fixes. Every Tier-2/3 number goes
through the same tested v2 scorer as chest and the four anatomies, or it is not reported. That
scorer (Absent projection, list evidence, runtime-taxonomy anatomy path via `evaluate_transfer`,
runtime M12 lexicon, teacher-reference M5/M12, patient-bootstrap CIs) is now **the critical path**.
It needs to be committed with tests by **10-14**.

---

## 1. Tier 2 — mammography

### 1.1 Make the calcification call stop blocking (T2.0, CPU, today)
No `configs/taxonomies/mammography.yaml` exists in the mirror, and the clinician hasn't signed the
cyst / benign-calcification call (`calcificat` 70.0%, `nodul` 68.9% of reports). Don't run the
teacher twice, once per reading. Instead:

- **Give the contested findings their own labels**: e.g. `Benign-appearing Calcifications`,
  `Simple Cyst`, `Post-surgical Change`, separate from `Suspicious Calcifications`, `Mass`,
  `Architectural Distortion`, `Asymmetry`, `Skin/Nipple Change`, `Axillary Lymphadenopathy`.
  **Breast density stays a descriptor, not a finding** (normalcy §3.1). Aim for ~25–35 labels,
  like the other anatomies.
- **Make `is_normal` a deterministic function of the findings under two named readings**:
  - **A (chest convention, primary):** any Present/Uncertain finding ⇒ abnormal.
  - **B (screening convention):** the same, ignoring the benign-labelled set.
  The teacher emits findings once. Teacher and student `is_normal` are each recomputed from their
  own findings under A and B, using the same function. Report M3/M4/κ under both as an interval.
- Record both readings, the benign set and the mapping in DECISIONS **before** labeling. One teacher
  pass instead of two. The clinician's eventual call picks which end of the interval is the result,
  with no relabeling.

### 1.2 Split and leakage (CPU)
Use the **locked Phase-0 patient split**. `internal_other` was already assigned from the same
patient pool as chest, so this gives zero chest-test overlap by construction (unlike the
re-seeded anatomy split, #11 §3.4). Effective unique 6,859 / 8,972 patients / 1,088 shared with
chest. Then apply the L1–L4 rules from #07 §4.4 against chest **and** spine/extremity, plus a
token-length dry run (prompt + target, max vs the ~4,700 wall). Mammo reports are long by
radiograph standards (median 357 chars), but should still be far below it.

### 1.3 Runs
| # | Run | GPU | Reads against |
|---|---|---|---|
| T2.1a | Capacity probe: W0-1c contract on the 256 longest mammo reports | ~15 min | at cap ≤ 1%, validity ≥ 0.99 (same gate as T1.2) |
| T2.1 | Teacher v2, all 6,859, 2 hash shards; + T=0.1 replica on a fixed 1,000 | ~1 h wall on 2 GPUs | merge invariants; teacher ceiling |
| T2.2 | Zero-shot: **T1.3** and **T1.4 s17** with the mammo list; base E4B; lexical floor | ~1 h | same reference pack as T1.0 |
| T2.3 | Joint: chest 44,808 + spine/extremity train + mammo train, **s17 and s23** | ~15 h each | chest M1 within 0.01 of T1.4; spine/extremity not below T1.4 beyond CI; mammo vs T2.2 |
| T2.3b *(optional)* | Mammo-only LoRA (separate adapter, multi-LoRA option) | ~2–3 h | vs T2.3 on mammo; answers "joint vs separate" directly |

**Gate for starting T2.3 (write it down first):** P0 items 1–4 read, T2.1 passes its merge gate, and
T2.2 has been scored. Comparator framing: **A (extraction fidelity) is the deliverable, C (BI-RADS)
is retired.** Record that as an owner decision; it has been open since #07.

---

## 2. Tier 3 — CT

### 2.1 First, pin down which data is coming
- **CT-RATE** is distributed on Hugging Face under **CC-BY-NC-SA 4.0**, not via PhysioNet. That's
  fine for a research paper, but this is a commercial entity, so get a **written legal note**
  (H5, open since #07) and a DECISIONS entry before any CT-RATE text reaches the teacher. Check on
  arrival: counts, report provenance (I believe the reports were translated into English; confirm
  it, because it matters for the same reason as `Report_English`), and the official train/valid
  split. Use their **validation split as our test**.
- **PhysioNet credentialing** separately unlocks **RadGraph-XL** (radiologist-annotated CT/MR/CXR,
  the external anchor in `d3` E5), **MIMIC-IV-Note** (CT/MR/US report volume) and **MIMIC-CXR**
  (the public chest replication #11 asks for). If both arrive, CT-RATE is the volume and
  RadGraph-XL is the anchor.

### 2.2 Experiments (each answers one `d3` §11.4 question)
| # | Experiment | Question it answers | GPU |
|---|---|---|---|
| T3.0 | **Token-length study** (Gemma tokenizer): teacher prompt + report + expected output vs `max_model_len` / KV; student prompt + report + target vs ~4,700 | "Is sequence length the blocker?" Decide this first; it's cheap | 0 |
| T3.1 | CT taxonomy (~30–40 labels) + normalcy + study-type string, **provisional**. Seed from the chest X-ray labels that carry over (consolidation, effusion, nodule, cardiomegaly…) plus CT-specific ones (ground-glass, emphysema, bronchiectasis, mosaic attenuation, coronary calcification, lymphadenopathy…), and map to CT-RATE's own abnormality classes where possible. **Record how many labels overlap the chest taxonomy**: it becomes a variable in the portability story | 0 |
| T3.2 | Teacher capacity probe: 256 longest + 1,000 random, W0-1c contract | CT outputs will be longer (more findings per report); expect at-cap > 1% at 2,048. If so: cap 3,072 + re-derived `max_model_len`, rerun **only** the probe, and record it. Never edit a gate after a result | ~1 h |
| T3.3 | Teacher labeling: ~8–10k unique train reports (patient-disjoint, official train split) + the official validation split; T=0.1 replica on 1,000 test reports | Builds the reference | ~3–5 h wall on 2 GPUs (verify the rate in T3.2) |
| T3.4 | **Zero-shot**: T1.4 s17 (and T2.3 if ready) with the CT list; base E4B; lexical floor; teacher replica as ceiling | "Does the radiograph adapter transfer across modality?" Strongest possible N1 result if yes | ~1–2 h |
| T3.5 | **CT LoRA, cold vs warm start**, at **2k and ~8k** train reports: (a) from base E4B, (b) continued from T1.4 s17 | "Does radiograph distillation buy sample efficiency on a new modality?" A 2×2 that publishes well whatever the outcome, and it is the honest version of "needs a separate adapter" | 4 runs, ~2–6 h each |
| T3.6 | External agreement: teacher and student vs **CT-RATE's provided labels** on the overlapping classes; RadGraph-XL entity-level grounding if PhysioNet lands | Agreement with an **external labeler**, not accuracy (CT-RATE's labels are themselves model-derived; verify) | 0–1 h |

`d3` §11.4 says separate adapter, not joint, for CT. Keep that: **no CT data enters the
chest/radiograph adapter in this window.** "Not yet" stays a permitted conclusion at every step.

---

## 3. Tier 1 items that must still finish (from #11)

These are in the board below and aren't optional. Tier 2/3 numbers are meaningless without the
fixed scorer, and the paper needs the controls.

- **P0 (CPU):** M5 diagnosis with the v2 teacher's own M5; M2 decomposition + label hygiene;
  anatomy metrics via `evaluate_transfer`; M12 fixed; CIs everywhere; same-function ceilings;
  scorer + tests committed; train/test exact-text overlap.
- **P1 (GPU):** `3.45k-nt` (trace confound), T1.3 s23, M8 warm benchmark, IU/Open-i replication.
- **Deferred:** P-split-C side arm, N2/E2.4–E2.6, LOAO (LOAO only if a GPU is idle; it is the
  best paper experiment among the deferred ones).

---

## 4. Board (4× H100)

| Day | GPU 1 | GPU 2 | GPU 3 | GPU 4 | CPU / people |
|---|---|---|---|---|---|
| **10-13 Tue** | `3.45k-nt` (~10 h) | T1.3 s23 (~10 h) | M8 benchmark → IU/Open-i replication | T2.1a mammo probe (as soon as the taxonomy is in) | **v2 scorer fixes + tests**; mammo taxonomy + readings A/B + split; DECISIONS (Tier-2 comparator, mammo normalcy mapping, CT-RATE licence, T2/T3 gates); legal + clinician + ethics requests out |
| **10-14 Wed** | → free | → free | T2.1 shard 0 → T2.2 zero-shot | T2.1 shard 1 → T=0.1 replica | P0 readout (M5, M2, anatomy, M12, CIs); score T2.2; CT data ingest + T3.0 lengths |
| **10-15 Thu** | **T2.3 s17** (~15 h), only if the T2.3 gate passes | **T2.3 s23** | T3.2 CT capacity probe | T3.1 taxonomy review / T3.3 starts if T3.2 passes | CT taxonomy; Tier-1 readout draft |
| **10-16 Fri** | T2.3 → T2.4 eval | T2.3 → T2.4 eval | T3.3 CT teacher shard 0 | T3.3 shard 1 + replica | |
| **10-19 Mon** | T2.4 scoring passes (chest, 4 anatomies, mammo; both seeds) | T2.3b mammo-only *(opt.)* | **T3.4** CT zero-shot | T3.5 cold 2k | T2.4 readout |
| **10-20 Tue** | LOAO *(if idle)* | | T3.5 warm 2k → cold 8k | T3.5 warm 8k | T3.6 external agreement |
| **10-21 → 10-23** | buffer / reruns | | T3 scoring | | Tier-2 + Tier-3 readouts |
| **10-26 →** | — | | | | consolidated claims doc → paper outline |

Estimates come from measured rates (teacher ~1.45 rows/s/GPU on radiographs, training ~25 s/step).
CT rates are unknown until T3.2. This project's estimates have always run long, so the buffer
is real.

---

## 5. What to send back

1. 10-14: scorer committed (test list from #11 §3.1), P0 readout, mammo taxonomy + DECISIONS numbers.
2. After T2.1/T2.2 and T3.2: the self-describing aggregates (#07 §0.1 item 5), each against its
   pre-written gate.
3. Human and legal status every readout: clinician (mammo + 4 anatomies), legal (CT-RATE,
   Gemma output terms), ethics/IRB, PhysioNet. Include "not started" when that's the truth.
