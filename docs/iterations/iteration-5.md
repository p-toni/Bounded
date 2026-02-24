# Iteration #5 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Schedule-driven deterministic rotation for W1.
- Curvature-triggered audit insertion in W1 pack generation.
- Deterministic answer-key generation remains valid for all generated drills.
- Audit completion updates scheduler state.

## Checklist
- [x] Add `Workflows::RotationPolicy` service with weekday map and audit cadence.
- [x] Add curvature-window trigger for audit insertion.
- [x] Wire W1 `generate_drill_instances` to use rotation policy outputs.
- [x] Include audit context (`candidate_spans`, `correct_span_ids`) in generation context.
- [x] Update engine `GenerateSessionPack` to normalize rotation and support audit slot.
- [x] Persist schedule state updates from W1 generation.
- [x] Mark audit completion in schedule state after successful W2 audit.
- [x] Add/extend engine tests for normalized rotation + audit slot.
- [x] Update workflow/guardrail docs.
- [x] Run CI sanity (`make ci`) with passing result.

## Files changed (high-level)
- `rails-app/app/services/workflows/rotation_policy.rb`
- `rails-app/app/services/workflows/gateway.rb`
- `engine-ruby/lib/geometry_gym_engine/drills/generate_session_pack.rb`
- `engine-ruby/lib/geometry_gym_engine/drills/answer_key_builder.rb`
- `engine-ruby/spec/generate_session_pack_spec.rb`
- `docs/workflows.md`
- `docs/guardrails.md`
