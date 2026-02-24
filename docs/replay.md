# Replay Model

Replay inputs:
- `workflow_runs` record
- ordered `workflow_step_events`

Integrity checks:
- `input_hash` and `output_hash` per step
- `tool_schema_version` alignment
- monotonic workflow state transitions

Compaction strategy (V1 baseline):
- hot full events (30 days)
- warm compacted snapshots with hash pointers (planned evolution)
- cold archive retention (365 days)


Signed compaction snapshot:
- retention job writes snapshot payload for closed runs
- payload hash is HMAC-signed (`WORKFLOW_SNAPSHOT_HMAC_SECRET`)
- step events are pruned only after signature verification
