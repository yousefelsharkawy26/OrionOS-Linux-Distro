# =============================================================================
# OrionOS Build System
# A modern, performance-focused Linux distribution based on Arch Linux
# =============================================================================

# Build configuration
BUILD_DIR ?= $(PWD)/build
ISO_DIR ?= $(BUILD_DIR)/iso
PKG_DIR ?= $(BUILD_DIR)/packages
KERNEL_DIR ?= $(BUILD_DIR)/kernel
PROFILE ?= default
ARCH ?= x86_64
VERSION ?= $(shell cat $(PWD)/VERSION 2>/dev/null || echo "0.1.0-alpha")
CODENAME ?= "Nebula"
RELEASE_DATE := $(shell date +%Y%m%d)

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Targets
.PHONY: all clean iso kernel packages repo install-desktop install-services \
        test release sign-db update-pkgs docker-build help

# Default target: build everything
all: info repo kernel packages iso

# Display build information
info:
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(BLUE)║$(RESET)              $(GREEN)OrionOS Build System$(RESET)                    $(BLUE)║$(RESET)"
	@echo "$(BLUE)║$(RESET)  Version:   $(YELLOW)$(VERSION)$(RESET)                                 $(BLUE)║$(RESET)"
	@echo "$(BLUE)║$(RESET)  Codename:  $(YELLOW)$(CODENAME)$(RESET)                                $(BLUE)║$(RESET)"
	@echo "$(BLUE)║$(RESET)  Arch:      $(YELLOW)$(ARCH)$(RESET)                                    $(BLUE)║$(RESET)"
	@echo "$(BLUE)║$(RESET)  Profile:   $(YELLOW)$(PROFILE)$(RESET)                                 $(BLUE)║$(RESET)"
	@echo "$(BLUE)║$(RESET)  Date:      $(YELLOW)$(RELEASE_DATE)$(RESET)                            $(BLUE)║$(RESET)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(RESET)"

# Initialize build environment
init:
	@echo "$(GREEN)[INIT]$(RESET) Initializing OrionOS build environment..."
	@mkdir -p $(BUILD_DIR)/{iso,packages,kernel,repo,logs}
	@scripts/build/init-env.sh $(ARCH)
	@echo "$(GREEN)[INIT]$(RESET) Build environment ready."

# Build custom kernel
kernel:
	@echo "$(GREEN)[KERNEL]$(RESET) Building OrionOS custom kernel..."
	@$(MAKE) -C kernel build BUILD_DIR=$(KERNEL_DIR) ARCH=$(ARCH)
	@echo "$(GREEN)[KERNEL]$(RESET) Kernel build complete."

# Build all packages
packages:
	@echo "$(GREEN)[PKGS]$(RESET) Building OrionOS package repository..."
	@scripts/build/build-packages.sh $(PKG_DIR) $(ARCH) $(PROFILE)
	@echo "$(GREEN)[PKGS]$(RESET) Package build complete."

# Create local repository
repo: packages
	@echo "$(GREEN)[REPO]$(RESET) Creating package repository..."
	@scripts/build/create-repo.sh $(PKG_DIR) $(BUILD_DIR)/repo
	@echo "$(GREEN)[REPO]$(RESET) Repository created."

# Generate ISO image
iso: kernel repo
	@echo "$(GREEN)[ISO]$(RESET) Generating OrionOS ISO image..."
	@scripts/build/build-iso.sh \
		--arch $(ARCH) \
		--profile $(PROFILE) \
		--version $(VERSION) \
		--output $(ISO_DIR)/orionos-$(VERSION)-$(ARCH).iso
	@echo "$(GREEN)[ISO]$(RESET) ISO generated: $(ISO_DIR)/orionos-$(VERSION)-$(ARCH).iso"

# Install desktop environment
install-desktop:
	@echo "$(GREEN)[DESKTOP]$(RESET) Installing OrionOS desktop environment..."
	@scripts/install/install-desktop.sh $(PROFILE)
	@echo "$(GREEN)[DESKTOP]$(RESET) Desktop environment installed."

# Install system services
install-services:
	@echo "$(GREEN)[SERVICES]$(RESET) Installing OrionOS system services..."
	@scripts/install/install-services.sh
	@echo "$(GREEN)[SERVICES]$(RESET) System services installed."

# Run all tests
test:
	@echo "$(GREEN)[TEST]$(RESET) Running OrionOS test suite..."
	@scripts/testing/run-tests.sh $(BUILD_DIR)/logs
	@echo "$(GREEN)[TEST]$(RESET) Tests complete."

# Sign package database
sign-db:
	@echo "$(GREEN)[SIGN]$(RESET) Signing package database..."
	@scripts/build/sign-repo.sh $(BUILD_DIR)/repo
	@echo "$(GREEN)[SIGN]$(RESET) Database signed."

# Update package versions from upstream
update-pkgs:
	@echo "$(GREEN)[UPDATE]$(RESET) Updating package versions..."
	@scripts/maintain/update-packages.sh
	@echo "$(GREEN)[UPDATE]$(RESET) Package update check complete."

# Build in Docker container
docker-build:
	@echo "$(GREEN)[DOCKER]$(RESET) Building in Docker container..."
	@scripts/build/docker-build.sh $(ARCH) $(VERSION)
	@echo "$(GREEN)[DOCKER]$(RESET) Docker build complete."

# Create release
release: clean all sign-db
	@echo "$(GREEN)[RELEASE]$(RESET) Creating release $(VERSION)..."
	@scripts/build/create-release.sh \
		--version $(VERSION) \
		--iso $(ISO_DIR)/orionos-$(VERSION)-$(ARCH).iso \
		--repo $(BUILD_DIR)/repo \
		--output $(BUILD_DIR)/release
	@echo "$(GREEN)[RELEASE]$(RESET) Release $(VERSION) ready."

# Clean build artifacts
clean:
	@echo "$(YELLOW)[CLEAN]$(RESET) Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)/{iso,packages,kernel,logs}
	@echo "$(YELLOW)[CLEAN]$(RESET) Build artifacts cleaned."

# Deep clean (including cached sources)
distclean: clean
	@echo "$(YELLOW)[DISTCLEAN]$(RESET) Deep cleaning all artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "$(YELLOW)[DISTCLEAN]$(RESET) All artifacts removed."

# Help
help:
	@echo "$(BLUE)OrionOS Build System - Available Targets:$(RESET)"
	@echo ""
	@echo "  $(GREEN)all$(RESET)              - Build everything (repo, kernel, packages, iso)"
	@echo "  $(GREEN)init$(RESET)             - Initialize build environment"
	@echo "  $(GREEN)kernel$(RESET)           - Build custom kernel"
	@echo "  $(GREEN)packages$(RESET)         - Build all packages"
	@echo "  $(GREEN)repo$(RESET)             - Create package repository"
	@echo "  $(GREEN)iso$(RESET)              - Generate ISO image"
	@echo "  $(GREEN)install-desktop$(RESET)  - Install desktop environment"
	@echo "  $(GREEN)install-services$(RESET) - Install system services"
	@echo "  $(GREEN)test$(RESET)             - Run test suite"
	@echo "  $(GREEN)sign-db$(RESET)          - Sign package database"
	@echo "  $(GREEN)update-pkgs$(RESET)      - Update package versions"
	@echo "  $(GREEN)docker-build$(RESET)     - Build in Docker"
	@echo "  $(GREEN)release$(RESET)          - Create release"
	@echo "  $(GREEN)clean$(RESET)            - Clean build artifacts"
	@echo "  $(GREEN)distclean$(RESET)        - Deep clean everything"
	@echo "  $(GREEN)help$(RESET)             - Show this help"
	@echo ""
	@echo "$(BLUE)Variables:$(RESET)"
	@echo "  PROFILE=$(PROFILE)  - Build profile (default/gaming/developer/minimal)"
	@echo "  ARCH=$(ARCH)        - Target architecture"
	@echo "  VERSION=$(VERSION)  - Release version"
