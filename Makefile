# OrionOS Makefile

.PHONY: all init kernel packages iso repo test docker-iso clean help

VERSION ?= 1.0.0
PROFILE ?= default
ARCH ?= x86_64
BUILD_DIR = build
OUTPUT_DIR = $(BUILD_DIR)/iso
WORK_DIR = $(BUILD_DIR)/work

all: iso

help:
	@echo "OrionOS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make init          - Initialize build environment (requires Arch Linux)"
	@echo "  make packages      - Build OrionOS packages"
	@echo "  make kernel        - Build custom kernel"
	@echo "  make iso           - Generate ISO image (native, requires Arch Linux)"
	@echo "  make docker-iso    - Generate ISO via Docker (any Linux)"
	@echo "  make repo          - Create package repository"
	@echo "  make test          - Run test suite"
	@echo "  make clean         - Clean build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION=$(VERSION)"
	@echo "  PROFILE=$(PROFILE)  (default|gaming|developer|minimal)"
	@echo "  ARCH=$(ARCH)"

init:
	@bash scripts/build/init-env.sh $(ARCH)

packages:
	@bash scripts/build/build-packages.sh

kernel:
	@bash scripts/build/build-kernel.sh

iso:
	@bash scripts/build/build-iso.sh --version $(VERSION) --profile $(PROFILE) --arch $(ARCH)

docker-iso:
	@bash scripts/build/build-iso-host.sh

repo:
	@bash scripts/build/create-repo.sh

test:
	@bash testing/run-tests.sh

clean:
	rm -rf $(BUILD_DIR)/work
	rm -rf $(BUILD_DIR)/iso/*.iso
	rm -rf $(BUILD_DIR)/iso/*.sha256
	rm -rf $(BUILD_DIR)/iso/*.sha512
	rm -rf $(BUILD_DIR)/iso/*.md5
	@echo "Build artifacts cleaned"
