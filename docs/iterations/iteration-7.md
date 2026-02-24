# Iteration #7 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Close full scored rep execution gap by adding session drill submission (`Attempt` + deterministic `Score`) for session packs.
- Implement score-freeze transition when session pack drills are fully scored.
- Enforce graph granularity caps/windows as non-bypassable gate in W1.

## Checklist
- [x] Add graph granularity validator service with v0 thresholds.
- [x] Gate W1 on granularity after anchor evidence validation.
- [x] Enforce model caps for node/edge and anchor-edge upper bounds.
- [x] Add session attempt submission service with immutable binding checks.
- [x] Persist deterministic score for each submitted drill.
- [x] Auto-freeze session pack after all drill attempts are scored.
- [x] Add route/controller for session attempt submission.
- [x] Add migration for attempt idempotency index and edge anchor lookup index.
- [x] Add specs for graph granularity and session rep submission behavior.
- [x] Update protocol/workflow/guardrail docs.
- [x] Run CI sanity (`make ci`) with passing result.

## Validation
- `make ci`: PASS
- `bundle exec rspec` in `/Users/ptoni/Downloads/Projects/Bounder/rails-app`: NOT RUN (missing gem executable; requires `bundle install`)

## Files changed (high-level)
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/graph_granularity.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/session_rep_submit.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/session_attempts_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/config/routes.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/gateway.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/models/node.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/models/edge.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/db/migrate/20260224102000_add_iteration7_constraints.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/graph_granularity_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/session_rep_submit_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/session_attempts_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/workflows.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/guardrails.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/protocol.md`
