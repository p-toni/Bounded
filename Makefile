.PHONY: test-schemas test-engine test-rails test-replay ci

test-schemas:
	python3 -c "import glob,json; files=glob.glob('schemas/v1/*.json'); assert files, 'No schemas found'; [json.load(open(p)) for p in files]; print(f'validated {len(files)} schemas')"

test-engine:
	cd engine-ruby && ruby -Ilib -I./spec ./spec/paragraph_spans_spec.rb && \
	ruby -Ilib -I./spec ./spec/schedule_queue_spec.rb && \
	ruby -Ilib -I./spec ./spec/generate_session_pack_spec.rb && \
	ruby -Ilib -I./spec ./spec/score_spec.rb && \
	ruby -Ilib -I./spec ./spec/answer_key_validation_spec.rb && \
	ruby -Ilib -I./spec ./spec/score_diagnostics_spec.rb && \
	ruby -Ilib -I./spec ./spec/replay_spec.rb && \
	ruby -Ilib -I./spec ./spec/xp_spec.rb && \
	ruby -Ilib -I./spec ./spec/ous_spec.rb

test-rails:
	cd rails-app && bundle exec rspec

test-replay:
	python3 -c "import json; data=json.load(open('fixtures/workflow_replays/sample_run.json')); assert data['workflow_run']['status'] in ['succeeded','failed','canceled']; print('workflow replay fixture ok')"

ci: test-schemas test-engine test-replay
