# Geometry Gym V1 Monorepo

Protocol-first, deterministic-first implementation baseline.

## Layout
- `schemas/v1`: Canonical JSON contracts.
- `engine-ruby`: Deterministic learning engine reference implementation.
- `adapter-ruby-gem`: Thin Ruby adapter over canonical contracts.
- `rails-app`: Rails 8 reference app with workflow runner + ActionCable streaming.
- `fixtures`: Gold-set and replay fixtures.

## Quick commands
- `make test-schemas`
- `make test-engine`
- `make test-rails`
- `make test-replay`
- `make ci`
