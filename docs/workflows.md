# Workflow Definitions (V1)

## URL Ingest
- Endpoint: `POST /sources/ingest`.
- Fetches URL, extracts readable text, creates paragraph-level spans, and persists `Source` + `SourceVersion` + `SourceSpan`.
- Bootstraps `Topic` and initial `GraphVersion(v1)` for the user when absent.

## W1 Prepare Today's Rep
- Resolve topic and latest versions.
- If `topic_id` is absent, build a deterministic schedule queue from persisted schedule state, audit cadence, and recent curvature.
- Validate anchor evidence.
- Enforce progression-aware granularity gate before session generation:
  - graph-level caps are unlocked by tier (`graph_level` 0/1/2)
  - level 0 starts narrow; higher node/edge/anchor maxima require promotion
- Generate deterministic drill instances using schedule-driven rotation.
- Always include `rebuild`, then day-based diagnostics filtered by unlocked diagnostics, and include `audit` when due or curvature-triggered.
- Persist session pack.

## Session Drill Submission
- Endpoint: `POST /session_packs/:session_pack_id/attempts`.
- Persists deterministic `Attempt` + `Score` for one drill instance.
- Enforces immutable binding checks (`graph_version`, `source_version`, `rubric_version`).
- Enforces diagnostic unlock gates from progression tier (locked diagnostics are rejected).
- Enforces canonical 8-minute runtime script:
  - drill order must follow `session_pack.drill_instance_ids` (state machine, no skips)
  - first drill must be `rebuild`
  - phase budgets are fixed to `0-2`, `2-4`, `4-6`, `6-8` minutes
  - a submission is rejected if duration breaches phase or total 8-minute budget
- Mints deterministic XP events for scored reps (including direct session submissions) and applies fluency penalty when geometry actions are absent.
- Emits curvature diagnostics (`missing_constraint`, `hidden_coupling`) and returns recent curvature stream in rep result payload.
- Auto-freezes `session_pack.score_frozen_at` once all drills in the pack have scored attempts.

## W2 Run Reality Audit
- Stage A creates audit drill and waits for user input.
- Stage B records attempt, computes deterministic score, records edge audit, computes XP, recomputes schedule, and refreshes topic OUS.

## W3 Post-session Debrief
- Requires frozen score.
- Builds deterministic summary, optional LLM critique.
- Scout may be invoked only post-freeze and is constrained to: 2 edge-targeted counterexamples, 1 alternate framing, 1 failure mode.

## W4 Evidence Assist
- Read-only candidate ranking via LLM.
- No persistence; user must attach evidence explicitly.

## W5 Render Share Pack
- Requires frozen snapshot.
- Renders markdown/image artifacts.

## Run Inspector
- Human-readable inspector UI at `/workflow_runs/:id/inspector`.
- Shows step timeline, hash integrity fields, and tool call logs.
- Supports query filters: `step_name`, `step_status`, `tool_name`.
- Replay API remains canonical at `/workflow_runs/:id/replay`.

## OUS Surface
- Endpoint: `GET /topics/:topic_id/score`.
- Returns persisted `TopicScore` (`ous_raw_float`, `ous_display_float`, `spaced_count_int`), computing one if absent.
- Applies deterministic cold-start confidence (first 10 scored attempts) and overdue decay from `edge_mastery` (`last_seen_at` + `mastery_float`).

## Curvature Surface
- Endpoint: `GET /topics/:topic_id/curvature_signals`.
- Returns the standalone curvature diagnostic stream for the topic (`hidden_coupling`, `missing_constraint`) in reverse-chronological order.

## Privacy Controls
- Approval token issue: `POST /approval_tokens` with `action` + `scope`.
- Export bundle (token-gated): `POST /exports/bundle`.
- Hard delete scope (token-gated): `POST /deletions`.
