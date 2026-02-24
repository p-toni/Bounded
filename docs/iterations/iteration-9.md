# Iteration #9 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Implement Scout post-freeze contract and gating in code (non-bypassable service path).
- Implement token-gated export and hard-delete operations for privacy/control.
- Tighten tool-surface guardrails for out-of-workflow access.

## Checklist
- [x] Add Scout schemas (`scout_output`, `scout_artifact`) to canonical schema repo.
- [x] Add `scout_artifacts` persistence model + migration.
- [x] Add `Workflows::ScoutPostFreeze` service with checks:
  - score-frozen gate
  - attempt-exists gate
  - output normalization to contract (2 counterexamples, 1 alternate framing, 1 failure mode)
- [x] Extend `Llm::OpenaiClient` with bounded `generate_scout` and deterministic fallback.
- [x] Add `Security::ApprovalTokens` issue/consume service with one-time consumption semantics.
- [x] Add `Workflows::ExportBundle` and `Workflows::DeleteScope` services.
- [x] Add API endpoints:
  - `POST /session_packs/:session_pack_id/scout`
  - `POST /approval_tokens`
  - `POST /exports/bundle`
  - `POST /deletions`
- [x] Add tool registry support:
  - `approval_token.issue`
  - `export.bundle`
  - `delete.scope`
  - `scout.invoke`
- [x] Restrict out-of-workflow tool calls to explicit allowlist in `Tools::Envelope`.
- [x] Add request/service specs for new routes/services.
- [x] Update docs (`workflows`, `guardrails`, `protocol`, `tool-envelopes`).
- [x] Run CI sanity (`make ci`) with passing result.

## Validation
- `make ci`: PASS
- `bundle exec rspec` in `/Users/ptoni/Downloads/Projects/Bounder/rails-app`: NOT RUN (missing gem executable; requires `bundle install`)

## Files changed (high-level)
- `/Users/ptoni/Downloads/Projects/Bounder/schemas/v1/scout_output.json`
- `/Users/ptoni/Downloads/Projects/Bounder/schemas/v1/scout_artifact.json`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/models/scout_artifact.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/security/approval_tokens.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/scout_post_freeze.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/export_bundle.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/delete_scope.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/llm/openai_client.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/scout_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/approval_tokens_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/exports_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/deletions_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/tools/registry.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/tools/envelope.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/config/routes.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/db/migrate/20260224131000_add_iteration9_scout_artifacts.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/db/migrate/20260224132000_add_iteration9_approval_token_index.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/approval_tokens_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/exports_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/deletions_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/scout_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/approval_tokens_service_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/scout_post_freeze_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/workflows.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/guardrails.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/protocol.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/tool-envelopes.md`
