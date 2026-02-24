# Tool Envelopes (V1)

## W1 Prepare Rep
Allow: schedule/topic/graph/source reads, drill_instance.create, session_pack.create.
Deny: attempt.create, score.compute, LLM freeform, deletes.

## W2 Reality Audit
Allow: drill_instance.create(audit), attempt.create, score.compute, edge_audit.record, xp.compute, schedule.recompute.
Deny: unrelated graph edits, share rendering, critique generation.

## W3 Debrief
Allow: score/attempt/graph/topic_score reads, debrief.create, optional critique_text.generate, scout.invoke.
Deny: score or attempt mutation.

## W4 Evidence Assist
Allow: source_span.list, edge.get, edge_evidence.suggest_candidates.
Deny: all writes.

## W5 Share Pack
Allow: frozen snapshot reads, share_pack.render.
Deny: graph edits and score mutation.

## Non-workflow Utilities
Allow: `source.ingest`, `source.get`, `source_version.get`, `source_span.get`, `topic_score.get`, `approval_token.issue`, `export.bundle`, `delete.scope`, `scout.invoke` through direct tool calls or API surfaces.
