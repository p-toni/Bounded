# Iteration #8 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Close URL ingest product-flow gap by exposing ingest through Rails API and persisting paragraph spans.
- Wire OUS computation into persisted `TopicScore` updates from scored attempts/workflows.
- Keep deterministic and guardrail semantics intact (no LLM in scoring/OUS paths).

## Checklist
- [x] Add `POST /sources/ingest` + `GET /sources/:id` API surface.
- [x] Implement `Workflows::SourceIngest` service using deterministic engine ingest/parse/segment modules.
- [x] Persist `Source`, `SourceVersion`, `SourceSpan`, and bootstrap `Topic` + initial `GraphVersion`.
- [x] Add ingest idempotency indexes (`source_versions[source_id,content_hash]`, `topics[user_id,source_id,title]`).
- [x] Add `Workflows::TopicScoreUpdater` service with deterministic component derivation and engine OUS compute.
- [x] Wire topic score refresh into `W2 Run Reality Audit` workflow and session drill submission service.
- [x] Add `GET /topics/:topic_id/score` endpoint.
- [x] Add `topic_score` canonical schema (`schemas/v1/topic_score.json`).
- [x] Update tool registry with source/topic-score parity calls.
- [x] Update docs (`workflows`, `guardrails`, `protocol`, `tool-envelopes`).
- [x] Run `make ci` with passing result.

## Validation
- `make ci`: PASS
- `bundle exec rspec` in `/Users/ptoni/Downloads/Projects/Bounder/rails-app`: NOT RUN (missing gem executable; requires `bundle install`)

## Files changed (high-level)
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/sources_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/topic_scores_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/source_ingest.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/topic_score_updater.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/engine_bridge.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/gateway.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/session_rep_submit.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/definitions/run_reality_audit.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/tools/registry.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/tools/envelope.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/config/routes.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/db/migrate/20260224114000_add_iteration8_ingest_indexes.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/schemas/v1/topic_score.json`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/sources_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/topic_scores_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/source_ingest_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/topic_score_updater_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/workflows.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/guardrails.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/protocol.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/tool-envelopes.md`
