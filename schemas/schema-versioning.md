# Schema Versioning Policy

## Canonical source
All canonical schemas live in `schemas/v1/*.json`. Any boundary object exchanged between UI, API, runner, engine, and fixtures must validate against these schemas.

## Required top-level fields
Every top-level object includes:
- `id`
- `schema_version`
- `created_at`

## Compatibility semantics
- `PATCH` (`x.y.Z`): additive, non-breaking, no semantic behavior change.
- `MINOR` (`x.Y.z`): additive fields/types; old fixtures and replay data must remain valid.
- `MAJOR` (`X.y.z`): breaking changes; requires migration notes and replay strategy.

## CI gates
- Schema JSON syntax and shape linting.
- Fixture validation against schema.
- Replay fixture compatibility check.
- Engine and Rails boundary validation tests.
