# Workflow Protocol Envelope (V1)

Required fields:
- `protocol_version`
- `workflow_run_id`
- `workflow_name`
- `event_seq`
- `timestamp`
- `event_type`
- `state`
- `cursor`
- `idempotency_key`
- `bound_versions`
- `payload`

Event types:
- `run.accepted`
- `step.started`
- `step.delta`
- `step.completed`
- `run.waiting_for_input`
- `run.canceled`
- `run.failed`
- `run.completed`

Transport defaults:
- WebSocket primary (`/cable`)
- SSE fallback for read-only streams
- HTTP for start/cancel/continue/replay endpoints

HTTP endpoints:
- `POST /workflow_runs`
- `POST /workflow_runs/:id/cancel`
- `POST /workflow_runs/:id/continue`
- `GET /workflow_runs/:id`
- `GET /workflow_runs/:id/events?cursor=...`
- `GET /workflow_runs/:id/replay`
- `GET /workflow_runs/:id/inspector?step_name=...&step_status=...&tool_name=...`
- `POST /session_packs/:session_pack_id/attempts`
- `POST /sources/ingest`
- `GET /sources/:id`
- `GET /topics/:topic_id/score`
- `GET /topics/:topic_id/curvature_signals`
- `POST /session_packs/:session_pack_id/scout`
- `POST /approval_tokens`
- `POST /exports/bundle`
- `POST /deletions`
