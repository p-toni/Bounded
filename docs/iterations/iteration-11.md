# Iteration #11 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Close remaining shape gaps for progression gates, game-loop unlock economy, and richer curvature diagnostics stream.
- Keep prior hardening guarantees intact (8-minute timer, OUS decay, strict schema runtime validation).

## Checklist
- [x] Add deterministic progression service with tier snapshots:
  - `edge_scout` (tier 0)
  - `map_apprentice` (tier 1)
  - `curvature_operator` (tier 2)
- [x] Enforce diagnostic unlock gates in session submission (`rephrase` / `teach` locked until promoted).
- [x] Upgrade granularity gate to progression-aware graph levels (`graph_level` 0/1/2 caps).
- [x] Wire rotation policy to unlocked diagnostics so early tiers cannot drift into fluency-heavy loops.
- [x] Add fluency penalty path in XP novelty behavior when no recent geometry action exists.
- [x] Mint XP events for scored direct session submissions (not only workflow-run paths).
- [x] Add deterministic curvature diagnostics service:
  - `missing_constraint` from high-confidence wrong predicts
  - `hidden_coupling` from repeated weak break failures across edges
  - short-window de-duplication
- [x] Expose standalone curvature stream endpoint: `GET /topics/:topic_id/curvature_signals`.
- [x] Add/extend specs for progression, rotation unlock filtering, graph progression gating, curvature detection, and session response surface.
- [x] Update docs (`workflows`, `guardrails`, `protocol`) to reflect progression and curvature stream semantics.

## Validation
- `make ci`: PASS
- `bundle exec rspec` full rails suite (local Postgres + `REDIS_URL`): PASS (`43 examples, 0 failures`)

## Files changed (high-level)
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/progression.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/graph_granularity.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/rotation_policy.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/curvature_diagnostics.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/session_rep_submit.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/curvature_signals_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/config/routes.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/models/xp_event.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/progression_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/rotation_policy_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/graph_granularity_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/curvature_diagnostics_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/session_rep_submit_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/curvature_signals_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/workflows.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/guardrails.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/protocol.md`
