# OrionOS Makefile

.PHONY: all init kernel packages iso repo test docker-iso clean help check-arch check-docker validate

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
	@echo "ISO Build Options:"
	@echo "  make iso           - Generate ISO (requires Arch Linux)"
	@echo "  make docker-iso    - Generate ISO via Docker (requires Docker)"
	@echo ""
	@echo "Other Targets:"
	@echo "  make validate      - Validate build profile without building"
	@echo "  make init          - Initialize build environment (Arch Linux only)"
	@echo "  make packages      - Build OrionOS packages"
	@echo "  make kernel        - Build custom kernel"
	@echo "  make repo          - Create package repository"
	@echo "  make test          - Run test suite"
	@echo "  make clean         - Clean build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION=$(VERSION)"
	@echo "  PROFILE=$(PROFILE)  (default|gaming|developer|minimal)"
	@echo "  ARCH=$(ARCH)"

check-arch:
	@if [ ! -f /etc/arch-release ]; then \
		echo ""; \
		echo "ERROR: ISO build requires Arch Linux or an Arch-based distribution."; \
		echo ""; \
		echo "Options:"; \
		echo "  1. Build on Arch Linux:"; \
		echo "       sudo pacman -S archiso base-devel"; \
		echo "       make iso"; \
		echo ""; \
		echo "  2. Use Docker (any Linux with Docker):"; \
		echo "       make docker-iso"; \
		echo ""; \
		echo "  3. Validate the profile (no build):"; \
		echo "       make validate"; \
		echo ""; \
		exit 1; \
	fi

check-docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "ERROR: Docker is not installed."; \
		echo "Install: https://docs.docker.com/get-docker/"; \
		exit 1; \
	fi
	@if ! docker info >/dev/null 2>&1; then \
		echo "ERROR: Docker daemon is not running."; \
		echo "Start with: sudo systemctl start docker"; \
		echo "Or on Ubuntu/Debian: sudo service docker start"; \
		exit 1; \
	fi

validate:
	@bash scripts/build/validate-profile.sh

init: check-arch
	@bash scripts/build/init-env.sh $(ARCH)

packages: check-arch
	@bash scripts/build/build-packages.sh

kernel: check-arch
	@bash scripts/build/build-kernel.sh

iso: check-arch
	@bash scripts/build/build-iso.sh --version $(VERSION) --profile $(PROFILE) --arch $(ARCH)

docker-iso: check-docker
	@bash scripts/build/build-iso-host.sh

repo: check-arch
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
