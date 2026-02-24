# Iteration #10 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Enforce canonical 8-minute rep script at runtime with a non-bypassable state machine.
- Implement OUS overdue/forgetting decay using `edge_mastery`.
- Upgrade runtime schema validation from required-key checks to strict canonical JSON Schema checks.

## Checklist
- [x] Enforce canonical runtime phase script in session submission:
  - rebuild-first gate
  - ordered drill progression gate
  - per-phase and total 8-minute duration caps
- [x] Return session timer state (`script_version`, elapsed/remaining budget, next phase) from session submission.
- [x] Update scored session submissions to refresh `edge_mastery` (`mastery_float`, `last_seen_at`) for touched edges.
- [x] Add overdue penalty derivation in `TopicScoreUpdater` using `edge_mastery.last_seen_at` and `mastery_float`.
- [x] Apply overdue penalty in engine OUS compute while preserving cold-start confidence penalty.
- [x] Replace shallow runtime schema checks with strict evaluator supporting:
  - `type`, `enum`, `const`
  - `minimum` / `maximum`
  - `minItems` / `maxItems`
  - `format` (`date-time`, `uri`)
  - `allOf`, `if/then`, local `$ref`
  - `additionalProperties`
- [x] Add/extend specs for:
  - canonical session script gating
  - edge mastery refresh from scored attempts
  - OUS overdue decay
  - strict schema runtime validation
- [x] Update docs (`workflows`, `guardrails`) for runtime timer and OUS decay semantics.

## Validation
- `make ci`: PASS
- `bundle exec rspec spec/services/session_rep_submit_spec.rb spec/services/topic_score_updater_spec.rb spec/services/schemas_validator_spec.rb` (with local Postgres): PASS (11 examples, 0 failures)
- `bundle exec rspec` full rails suite (with local Postgres + `REDIS_URL`): PASS (31 examples, 0 failures)

## Files changed (high-level)
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/session_rep_submit.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/topic_score_updater.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/schemas/validator.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/session_rep_submit_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/topic_score_updater_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/schemas_validator_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/engine-ruby/lib/geometry_gym_engine/ous/compute.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/engine-ruby/spec/ous_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/workflows.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/guardrails.md`
