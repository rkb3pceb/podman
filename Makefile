# Makefile for podman
# See docs/tutorials/podman_tutorial.md for usage

export GOPROXY ?= https://proxy.golang.org

PROJECT := github.com/containers/podman
GO ?= go
GOFLAGS ?= -trimpath
GO_BUILD = $(GO) build $(GOFLAGS)
GO_TEST = $(GO) test

# Version information
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null)
GIT_TAG ?= $(shell git describe --tags --abbrev=0 2>/dev/null)
BUILD_INFO ?= $(shell date +%s)
LDFLAGS_PODMAN ?= \
	-X $(PROJECT)/libpod/define.gitCommit=$(GIT_COMMIT) \
	-X $(PROJECT)/libpod/define.buildInfo=$(BUILD_INFO)

# Paths
BINDIR ?= $(DESTDIR)/usr/local/bin
LIBEXECDIR ?= $(DESTDIR)/usr/local/libexec
MANDIR ?= $(DESTDIR)/usr/local/share/man
COMPLETIONSDIR ?= $(DESTDIR)/usr/share/bash-completion/completions

# Binary names
BINARY ?= bin/podman
REMOTE_BINARY ?= bin/podman-remote

.DEFAULT_GOAL := all

.PHONY: all
all: binaries

.PHONY: binaries
binaries: podman podman-remote ## Build podman and podman-remote binaries

.PHONY: podman
podman: ## Build the podman binary
	$(GO_BUILD) -ldflags "$(LDFLAGS_PODMAN)" -o $(BINARY) ./cmd/podman

.PHONY: podman-remote
podman-remote: ## Build the podman-remote binary
	$(GO_BUILD) -ldflags "$(LDFLAGS_PODMAN)" -o $(REMOTE_BINARY) \
		-tags remote ./cmd/podman

.PHONY: test
test: unit integration ## Run all tests

.PHONY: unit
unit: ## Run unit tests
	# Use -count=1 to disable test result caching
	# Increased timeout to 5m to avoid flaky failures on slower machines
	$(GO_TEST) -v -count=1 -timeout 5m ./...

.PHONY: integration
integration: ## Run integration tests
	$(GO_TEST) -v -tags integration ./test/...

.PHONY: lint
lint: ## Run golangci-lint
	golangci-lint run

.PHONY: vendor
vendor: ## Update vendored dependencies
	$(GO) mod tidy
	$(GO) mod vendor
	$(GO) mod verify

.PHONY: install
install: install.bin install.man ## Install podman binaries and man pages

.PHONY: install.bin
install.bin:
	install -d $(BINDIR)
	install -m 755 $(BINARY) $(BINDIR)/podman

.PHONY: install.man
install.man:
	install -d $(MANDIR)/man1
	install -m 644 docs/source/markdown/*.1 $(MANDIR)/man1/ 2>/dev/null || true

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf bin/
	rm -f *.coverprofile

.PHONY: fmt
fmt: ## Format Go source files
	$(GO) fmt ./...

.PHONY: vet
vet: ## Run go vet
	$(GO) vet ./...

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
