# Iteration #6 Tracker

Status: COMPLETE
Completion: 100%

## Scope
- Deterministic schedule queue building for W1 topic selection when `topic_id` is not provided.
- Audit-cadence simulation fixtures and deterministic queue tests.
- Workflow run inspector filtering for faster debugging (`step_name`, `step_status`, `tool_name`).

## Checklist
- [x] Add engine module `Schedule::BuildQueue` with deterministic ranking and audit/curvature prioritization.
- [x] Add engine spec coverage for due-audit ordering and curvature priority.
- [x] Add audit-cadence simulation fixture and fixture-driven queue spec.
- [x] Wire Rails `resolve_topic` to deterministic queue selection path.
- [x] Add Rails `Workflows::ScheduleQueue` service to assemble queue context from DB.
- [x] Add inspector query filters and filtered counts in UI.
- [x] Add request spec for inspector filtering.
- [x] Add service spec for schedule queue composition.
- [x] Update docs (`workflows`, `guardrails`, `protocol`) for new behavior.
- [x] Run CI sanity (`make ci`) with passing result.

## Validation
- `make ci`: PASS
- `bundle exec rspec` in `/Users/ptoni/Downloads/Projects/Bounder/rails-app`: NOT RUN (missing gem executable; requires `bundle install`)

## Files changed (high-level)
- `/Users/ptoni/Downloads/Projects/Bounder/engine-ruby/lib/geometry_gym_engine/schedule/build_queue.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/engine-ruby/spec/schedule_queue_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/fixtures/goldset/v1/schedule/cadence_simulation.json`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/schedule_queue.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/gateway.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/services/workflows/engine_bridge.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/controllers/workflow_runs_controller.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/app/views/workflow_runs/inspector.html.erb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/requests/workflow_inspector_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/rails-app/spec/services/schedule_queue_spec.rb`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/workflows.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/guardrails.md`
- `/Users/ptoni/Downloads/Projects/Bounder/docs/protocol.md`
- `/Users/ptoni/Downloads/Projects/Bounder/Makefile`
