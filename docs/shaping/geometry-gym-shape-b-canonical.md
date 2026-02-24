---
shaping: true
---

# Geometry Gym — Shaping (Shape B selected, lock-ready)

## Requirements (R)

| ID   | Requirement                                                                                                                                                                                                           | Status    |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| R0   | Convert an article URL into owned understanding by forcing **source-closed reconstruction** (geometry, not retrieval)                                                                                                 | Core goal |
| R1   | Ingest from **article URL** reliably (fetch, parse to readable text, store)                                                                                                                                           | Must-have |
| R2   | Learning engine must be **science-grounded**: retrieval-first, spacing, interleaving, generation-before-help                                                                                                          | Must-have |
| R2.1 | Scoring must have a **truth model**: deterministic from rubrics + structured attempts; LLM may generate critique text but **must not decide scores**                                                                  | Must-have |
| R2.2 | Provide a **calibration gold-set** for v0 scoring (small seed set) and a harness to grow it                                                                                                                           | Must-have |
| R2.3 | Deterministic diagnostics must use **finite answer keys per drill instance** (valid paths/invariants/repairs), not only field shapes                                                                                  | Must-have |
| R3   | Represent understanding as **geometry**: nodes + typed edges (causal/constraint/tradeoff/dependency) + neighborhoods                                                                                                  | Must-have |
| R3.1 | Define **graph granularity rules** (what’s a node/edge in v0; limits; progression gates) so maps stay reconstructable                                                                                                 | Must-have |
| R3.2 | Prevent “mastering nonsense” by grounding edges: each **anchor edge** must carry **source evidence refs** (spans/quotes), and the system must run periodic **reality-audit drills** that verify edge↔source alignment | Must-have |
| R3.3 | Evidence spans must be **paragraph-level** for stability; UI may store optional sentence offsets inside a paragraph, but scoring keys depend only on paragraph span IDs                                               | Must-have |
| R4   | Built-in **anti-fluency guardrails**: Scout allowed only after attempt; rebuild-from-memory required; diagnostics enforce reconstruction                                                                              | Must-have |
| R4.1 | Scout gate must be an explicit contract (what’s blocked/unlocked pre/post attempt; what Scout can output)                                                                                                             | Must-have |
| R4.2 | Version integrity: every Attempt must bind immutable `graph_version`, `drill_instance_id`, and `rubric_version` so later edits cannot reinterpret past scores                                                         | Must-have |
| R5   | Daily usage fits a bounded loop: **5–12 minute sessions** that feel like reps, and **gamify geometry** so progress is earned by reconstruction/diagnostics (not passive consumption)                                  | Must-have |
| R5.1 | Sessions are short, repeatable, and end with a clear “rep result”                                                                                                                                                     | Must-have |
| R5.2 | Game mechanics reinforce geometry actions (edges, predictions, breaks, curvature) and penalize fluency-only behavior                                                                                                  | Must-have |
| R5.3 | Economy must be **anti-exploit**: repeating fluent behavior or using Scout to “sound right” must not score well                                                                                                       | Must-have |
| R5.4 | Define one canonical **8-minute rep script** (minute-by-minute) that fits the loop                                                                                                                                    | Must-have |
| R5.5 | Make the economy executable: define an XP function `xp = base * correctness * novelty_factor * spacing_factor` with decay windows and caps                                                                            | Must-have |
| R5.6 | No XP for a newly created edge until it passes ≥1 **Reality Audit (edge↔span)**                                                                                                                                       | Must-have |
| R6   | Privacy/control: user can **export/delete**, and sharing happens **outside the app via export artifacts** (no in-app social/feeds)                                                                                    | Must-have |
| R7   | Core should be **open-source** (protocol/engine), while still enabling a real product to exist on top                                                                                                                 | Must-have |
| R7.1 | 🟡 Protocol-first: **language-agnostic JSON Schemas are the source of truth**; reference Ruby implementation cannot redefine semantics                                                                                | Must-have |
| R7.2 | 🟡 Ruby gem is a **thin adapter** over JSON contracts; Rails uses the adapter but contracts remain canonical                                                                                                          | Must-have |
| R8   | Diagnostics must include the full set: **Rephrase, Rebuild, Predict, Teach, Break + Curvature**, with explicit session composition (not all six every day)                                                            | Must-have |
| R8.1 | OUS lifecycle: define cold-start and decay rules (pre-10 attempts, and how mastery fades/overdue reviews reduce score)                                                                                                | Must-have |
| R8.2 | Timer hygiene: Scout happens **after score freeze**, outside the scored 8-minute clock                                                                                                                                | Must-have |

---

## B: Protocol-First OSS Core + Rails Reference App (selected)

| Part   | Mechanism                                                                                                                                          |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **B1** | Open schemas + protocol for: Source, Graph, Drill, DrillInstance, Attempt, Score, CurvatureSignal                                                  |
| B1.1   | 🟡 JSON Schema repository is canonical; versioned via `schema_version` + compatibility rules                                                       |
| **B2** | OSS Learning Engine library: drill generation + scheduling + scoring (reference implementation in Ruby)                                            |
| B2.1   | Deterministic scoring from rubrics using structured answer formats (edge IDs, node IDs, choice IDs)                                                |
| B2.2   | LLM only for critique copy (“why you lost points”), never for score assignment                                                                     |
| B2.3   | Gold-set harness: fixtures + replay runner to validate scoring stability across versions                                                           |
| B2.4   | DrillInstance answer keys: generator emits `answer_key` (finite accepted sets) for each instance; scorer evaluates only against that key           |
| B2.5   | 🟡 Ruby implementation must validate I/O against JSON Schemas at boundaries (contract conformance)                                                 |
| **B3** | Rails webapp reference implementation consuming the engine                                                                                         |
| **B4** | Scenario packs: canonical drill templates + scoring rubrics for the six diagnostics                                                                |
| B4.1   | v0 calibration seed set + growth workflow (contrib format + CI checks)                                                                             |
| **B5** | Provider-agnostic Scout interface (OpenAI/Anthropic/local) gated by attempts                                                                       |
| B5.1   | Scout gate contract enforced by engine (no bypass from UI)                                                                                         |
| **B6** | Geometry game layer: progression driven by geometry ops (edge completion, prediction accuracy, break localization, curvature catches), not streaks |
| B6.1   | Anti-exploit economy: XP only from novel correct structure + spaced reviews; diminishing returns on repeats                                        |
| B6.2   | Executable XP function + caps (edge/day, topic/day), and spacing-dependent multipliers                                                             |
| B6.3   | Edge-churn guard: `edge.audit_passed_count == 0` ⇒ XP multiplier = 0 for any drill primarily rewarding that edge                                   |
| **B7** | External share artifacts: “Share Pack” exports (image/markdown) designed for posting outside app                                                   |
| **B8** | Grounding layer: paragraph spans + edge evidence refs + reality audits                                                                             |
| **B9** | Version integrity layer: immutable snapshots + attempt bindings                                                                                    |
| B9.1   | 🟡 Thin Ruby gem adapter that mirrors JSON types; cannot introduce “extra truth” not represented in schema                                         |

---

## Fit Check: R × B (selected shape only)

| Req  | Requirement                                                                                                                                                                                                           | Status    | B |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | - |
| R0   | Convert an article URL into owned understanding by forcing **source-closed reconstruction** (geometry, not retrieval)                                                                                                 | Core goal | ✅ |
| R1   | Ingest from **article URL** reliably (fetch, parse to readable text, store)                                                                                                                                           | Must-have | ✅ |
| R2   | Learning engine must be **science-grounded**: retrieval-first, spacing, interleaving, generation-before-help                                                                                                          | Must-have | ✅ |
| R2.1 | Scoring must have a **truth model**: deterministic from rubrics + structured attempts; LLM may generate critique text but **must not decide scores**                                                                  | Must-have | ✅ |
| R2.2 | Provide a **calibration gold-set** for v0 scoring (small seed set) and a harness to grow it                                                                                                                           | Must-have | ✅ |
| R2.3 | Deterministic diagnostics must use **finite answer keys per drill instance** (valid paths/invariants/repairs), not only field shapes                                                                                  | Must-have | ✅ |
| R3   | Represent understanding as **geometry**: nodes + typed edges (causal/constraint/tradeoff/dependency) + neighborhoods                                                                                                  | Must-have | ✅ |
| R3.1 | Define **graph granularity rules** (what’s a node/edge in v0; limits; progression gates) so maps stay reconstructable                                                                                                 | Must-have | ✅ |
| R3.2 | Prevent “mastering nonsense” by grounding edges: each **anchor edge** must carry **source evidence refs** (spans/quotes), and the system must run periodic **reality-audit drills** that verify edge↔source alignment | Must-have | ✅ |
| R3.3 | Evidence spans must be **paragraph-level** for stability; UI may store optional sentence offsets inside a paragraph, but scoring keys depend only on paragraph span IDs                                               | Must-have | ✅ |
| R4   | Built-in **anti-fluency guardrails**: Scout allowed only after attempt; rebuild-from-memory required; diagnostics enforce reconstruction                                                                              | Must-have | ✅ |
| R4.1 | Scout gate must be an explicit contract (what’s blocked/unlocked pre/post attempt; what Scout can output)                                                                                                             | Must-have | ✅ |
| R4.2 | Version integrity: every Attempt must bind immutable `graph_version`, `drill_instance_id`, and `rubric_version` so later edits cannot reinterpret past scores                                                         | Must-have | ✅ |
| R5   | Daily usage fits a bounded loop: **5–12 minute sessions** that feel like reps, and **gamify geometry** so progress is earned by reconstruction/diagnostics (not passive consumption)                                  | Must-have | ✅ |
| R5.1 | Sessions are short, repeatable, and end with a clear “rep result”                                                                                                                                                     | Must-have | ✅ |
| R5.2 | Game mechanics reinforce geometry actions (edges, predictions, breaks, curvature) and penalize fluency-only behavior                                                                                                  | Must-have | ✅ |
| R5.3 | Economy must be **anti-exploit**: repeating fluent behavior or using Scout to “sound right” must not score well                                                                                                       | Must-have | ✅ |
| R5.4 | Define one canonical **8-minute rep script** (minute-by-minute) that fits the loop                                                                                                                                    | Must-have | ✅ |
| R5.5 | Make the economy executable: define an XP function `xp = base * correctness * novelty_factor * spacing_factor` with decay windows and caps                                                                            | Must-have | ✅ |
| R5.6 | No XP for a newly created edge until it passes ≥1 **Reality Audit (edge↔span)**                                                                                                                                       | Must-have | ✅ |
| R6   | Privacy/control: user can **export/delete**, and sharing happens **outside the app via export artifacts** (no in-app social/feeds)                                                                                    | Must-have | ✅ |
| R7   | Core should be **open-source** (protocol/engine), while still enabling a real product to exist on top                                                                                                                 | Must-have | ✅ |
| R7.1 | 🟡 Protocol-first: **language-agnostic JSON Schemas are the source of truth**; reference Ruby implementation cannot redefine semantics                                                                                | Must-have | ✅ |
| R7.2 | 🟡 Ruby gem is a **thin adapter** over JSON contracts; Rails uses the adapter but contracts remain canonical                                                                                                          | Must-have | ✅ |
| R8   | Diagnostics must include the full set: **Rephrase, Rebuild, Predict, Teach, Break + Curvature**, with explicit session composition (not all six every day)                                                            | Must-have | ✅ |
| R8.1 | OUS lifecycle: define cold-start and decay rules (pre-10 attempts, and how mastery fades/overdue reviews reduce score)                                                                                                | Must-have | ✅ |
| R8.2 | Timer hygiene: Scout happens **after score freeze**, outside the scored 8-minute clock                                                                                                                                | Must-have | ✅ |

---

## Lock-in statement

- Shape **B** is selected.
- Paragraph-level `source_span_id` is locked.
- JSON Schemas are canonical; Ruby is the reference implementation; gem is adapter only.
- Trustworthiness hardening (grounding + deterministic keys + version integrity + executable economy + OUS lifecycle + timer hygiene) is locked.
