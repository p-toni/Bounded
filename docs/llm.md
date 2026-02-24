# LLM Integration (V1)

## Provider wiring
- Primary provider: OpenAI Responses API.
- Service: `rails-app/app/services/llm/openai_client.rb`.

## Allowed operations
- Evidence Assist ranking (`edge_evidence.suggest_candidates`).
- Optional Debrief critique (`critique_text.generate`).

## Policy controls
- Payload minimization per workflow.
- Redaction rules for emails and long numeric tokens.
- Logged fields: `policy_decision`, `redactions_applied_json`, `payload_hash`.
- Deterministic fallback path if API key/network/provider fails.

## Cache strategy
- Cache tuple: `workflow_name + schema_version + rubric_version + policy_version`.
- Sent via request metadata and `prompt_cache_key`.

## Environment variables
- `OPENAI_API_KEY`
- `OPENAI_MODEL` (default `gpt-5-mini`)
- `OPENAI_BASE_URL` (default `https://api.openai.com`)
- `OPENAI_TIMEOUT_SECONDS` (default `20`)
