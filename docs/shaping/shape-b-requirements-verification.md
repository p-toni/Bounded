# Shape B Requirements Verification

As of Iteration #11, all 27 locked Shape B requirements are implemented.

| ID | Status | Evidence |
| --- | --- | --- |
| R0 | Complete | `rails-app/app/services/workflows/session_rep_submit.rb` (`source_opened_bool` no-score behavior); `docs/guardrails.md` |
| R1 | Complete | `rails-app/app/services/workflows/source_ingest.rb`; `rails-app/app/controllers/sources_controller.rb` |
| R2 | Complete | `rails-app/app/services/workflows/rotation_policy.rb`; `rails-app/app/services/workflows/session_rep_submit.rb`; `docs/workflows.md` |
| R2.1 | Complete | `engine-ruby/lib/geometry_gym_engine/score/compute.rb`; `rails-app/app/services/workflows/session_rep_submit.rb` |
| R2.2 | Complete | `fixtures/goldset/v1/*`; `Makefile` (`test-replay`, schema/engine checks) |
| R2.3 | Complete | `engine-ruby/lib/geometry_gym_engine/drills/answer_key_builder.rb`; `engine-ruby/lib/geometry_gym_engine/score/validate_answer_key.rb` |
| R3 | Complete | `schemas/v1/node.json`; `schemas/v1/edge.json`; `rails-app/app/models/node.rb`; `rails-app/app/models/edge.rb` |
| R3.1 | Complete | `rails-app/app/services/workflows/graph_granularity.rb`; `rails-app/app/services/workflows/progression.rb`; `rails-app/spec/services/graph_granularity_spec.rb` |
| R3.2 | Complete | `engine-ruby/lib/geometry_gym_engine/graph/validate_anchor_evidence.rb`; `rails-app/app/services/workflows/gateway.rb` (`validate_anchor_evidence`, audit flow) |
| R3.3 | Complete | `engine-ruby/lib/geometry_gym_engine/segment/paragraph_spans.rb`; `rails-app/app/models/source_span.rb`; `schemas/v1/source_span.json` |
| R4 | Complete | `rails-app/app/services/workflows/scout_post_freeze.rb`; `rails-app/app/services/workflows/session_rep_submit.rb`; `docs/guardrails.md` |
| R4.1 | Complete | `schemas/v1/scout_output.json`; `rails-app/app/services/workflows/scout_post_freeze.rb`; `rails-app/spec/services/scout_post_freeze_spec.rb` |
| R4.2 | Complete | `rails-app/app/services/workflows/session_rep_submit.rb` (`validate_version_bindings!`); `schemas/v1/attempt.json` |
| R5 | Complete | `rails-app/app/services/workflows/session_rep_submit.rb`; `docs/workflows.md` |
| R5.1 | Complete | `rails-app/app/services/workflows/session_rep_submit.rb` (`session_timer`, freeze result) |
| R5.2 | Complete | `rails-app/app/services/workflows/progression.rb`; `rails-app/app/services/workflows/session_rep_submit.rb` (`fluency` penalty path) |
| R5.3 | Complete | `engine-ruby/lib/geometry_gym_engine/xp/compute.rb`; `rails-app/app/services/workflows/session_rep_submit.rb` (`source-open`, novelty/spacing, caps) |
| R5.4 | Complete | `rails-app/app/services/workflows/session_rep_submit.rb` (`CANONICAL_PHASES`, phase/total enforcement); `rails-app/spec/services/session_rep_submit_spec.rb` |
| R5.5 | Complete | `engine-ruby/lib/geometry_gym_engine/xp/compute.rb` (base \* correctness \* novelty \* spacing + caps) |
| R5.6 | Complete | `engine-ruby/lib/geometry_gym_engine/xp/compute.rb` (`audit_passed_count` gate); `rails-app/app/services/workflows/gateway.rb` (`record_edge_audit`) |
| R6 | Complete | `rails-app/app/services/security/approval_tokens.rb`; `rails-app/app/services/workflows/export_bundle.rb`; `rails-app/app/services/workflows/delete_scope.rb` |
| R7 | Complete | `engine-ruby/*`; `adapter-ruby-gem/*`; `schemas/v1/*` |
| R7.1 | Complete | `schemas/v1/*` canonical contracts; `rails-app/app/services/schemas/validator.rb` strict runtime validation |
| R7.2 | Complete | `adapter-ruby-gem/lib/geometry_gym/*`; `adapter-ruby-gem/spec/types_spec.rb` |
| R8 | Complete | `engine-ruby/lib/geometry_gym_engine/drills/generate_session_pack.rb`; `rails-app/app/services/workflows/rotation_policy.rb` |
| R8.1 | Complete | `engine-ruby/lib/geometry_gym_engine/ous/compute.rb`; `rails-app/app/services/workflows/topic_score_updater.rb`; `rails-app/app/models/edge_mastery.rb` |
| R8.2 | Complete | `rails-app/app/services/workflows/scout_post_freeze.rb` (post-freeze gate); `rails-app/app/services/workflows/session_rep_submit.rb` (scored timer enforcement) |

## Validation Summary
- `make ci`: PASS
- `rails-app` full suite: PASS (`43 examples, 0 failures`) in local Postgres + `REDIS_URL` environment.
