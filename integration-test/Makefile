REPO_ROOT := $(shell git rev-parse --show-toplevel)

.PHONY: ci-matrix
ci-matrix:
	@go test -list . -json . | jq -sc '[.[] | select(.Action=="output") | .Output | rtrimstr("\n") | select(startswith("Test"))]'

.PHONY: test/%
test/%:
	go test -v -timeout 60m -count=1 -run '^$*$$' ./...
