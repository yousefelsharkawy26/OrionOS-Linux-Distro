# ==============================================================================
# OrionOS Kernel Build System
# Builds the custom OrionOS kernel with CachyOS patches
# ==============================================================================

# Configuration
BUILD_DIR ?= $(PWD)/build
SRC_DIR ?= $(BUILD_DIR)/src
PKG_DIR ?= $(BUILD_DIR)/pkg
KERNEL_VERSION ?= 6.11
KERNEL_MAJOR ?= $(shell echo $(KERNEL_VERSION) | cut -d. -f1)
KERNEL_MINOR ?= $(shell echo $(KERNEL_VERSION) | cut -d. -f2)
ARCH ?= x86_64
NPROC ?= $(shell nproc)

# CachyOS patch source
CACHY_PATCH_URL ?= https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos

# Colors
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

.PHONY: all download extract patch configure build package clean distclean

# Default: full build pipeline
all: download extract patch configure build package

# ==============================================================================
# Download kernel sources
# ==============================================================================
download:
	@echo "$(BLUE)[KERNEL]$(RESET) Downloading Linux $(KERNEL_VERSION)..."
	@mkdir -p $(SRC_DIR)
	@if [ ! -f $(SRC_DIR)/linux-$(KERNEL_VERSION).tar.xz ]; then \
		echo "$(GREEN)[KERNEL]$(RESET) Downloading kernel tarball..."; \
		curl -L -o $(SRC_DIR)/linux-$(KERNEL_VERSION).tar.xz \
			https://cdn.kernel.org/pub/linux/kernel/v$(KERNEL_MAJOR).x/linux-$(KERNEL_VERSION).tar.xz; \
	else \
		echo "$(YELLOW)[KERNEL]$(RESET) Kernel tarball already downloaded"; \
	fi
	@echo "$(GREEN)[KERNEL]$(RESET) Download complete."

# ==============================================================================
# Download CachyOS patches
# ==============================================================================
download-patches:
	@echo "$(BLUE)[KERNEL]$(RESET) Downloading CachyOS patches..."
	@mkdir -p $(SRC_DIR)/patches
	@echo "$(GREEN)[KERNEL]$(RESET) Patching with CachyOS optimizations..."
	# BORE scheduler patch
	@curl -L -o $(SRC_DIR)/patches/0001-bore.patch \
		$(CACHY_PATCH_URL)/0001-bore.patch 2>/dev/null || \
		echo "$(YELLOW)[KERNEL]$(RESET) BORE patch - will use built-in"
	# Cachy base patch
	@curl -L -o $(SRC_DIR)/patches/0002-cachy-base.patch \
		$(CACHY_PATCH_URL)/0001-cachy-base.patch 2>/dev/null || \
		echo "$(YELLOW)[KERNEL]$(RESET) Cachy base patch - using defaults"
	# Additional optimizations
	@curl -L -o $(SRC_DIR)/patches/0003-optimizations.patch \
		$(CACHY_PATCH_URL)/0001-Optimize.patch 2>/dev/null || \
		echo "$(YELLOW)[KERNEL]$(RESET) Optimization patch - using defaults"
	@echo "$(GREEN)[KERNEL]$(RESET) Patch download complete."

# ==============================================================================
# Extract kernel sources
# ==============================================================================
extract:
	@echo "$(BLUE)[KERNEL]$(RESET) Extracting kernel sources..."
	@mkdir -p $(BUILD_DIR)
	@if [ ! -d $(BUILD_DIR)/linux-$(KERNEL_VERSION) ]; then \
		tar -xf $(SRC_DIR)/linux-$(KERNEL_VERSION).tar.xz -C $(BUILD_DIR); \
		echo "$(GREEN)[KERNEL]$(RESET) Extraction complete."; \
	else \
		echo "$(YELLOW)[KERNEL]$(RESET) Sources already extracted"; \
	fi

# ==============================================================================
# Apply patches
# ==============================================================================
patch: extract download-patches
	@echo "$(BLUE)[KERNEL]$(RESET) Applying patches..."
	@cd $(BUILD_DIR)/linux-$(KERNEL_VERSION) && \
	for p in $(SRC_DIR)/patches/*.patch; do \
		if [ -f "$$p" ]; then \
			echo "$(GREEN)[KERNEL]$(RESET) Applying $$(basename $$p)..."; \
			patch -p1 -i "$$p" --forward 2>/dev/null || \
			echo "$(YELLOW)[KERNEL]$(RESET) Skipping $$(basename $$p) (already applied or failed)"; \
		fi; \
	done
	@echo "$(GREEN)[KERNEL]$(RESET) Patching complete."

# ==============================================================================
# Configure kernel
# ==============================================================================
configure: patch
	@echo "$(BLUE)[KERNEL]$(RESET) Configuring kernel..."
	@cp $(PWD)/config/orionos-kernel.config \
		$(BUILD_DIR)/linux-$(KERNEL_VERSION)/.config
	@cd $(BUILD_DIR)/linux-$(KERNEL_VERSION) && \
		make olddefconfig ARCH=$(ARCH)
	@echo "$(GREEN)[KERNEL]$(RESET) Configuration complete."

# ==============================================================================
# Build kernel
# ==============================================================================
build: configure
	@echo "$(BLUE)[KERNEL]$(RESET) Building kernel with $(NPROC) jobs..."
	@cd $(BUILD_DIR)/linux-$(KERNEL_VERSION) && \
		make -j$(NPROC) ARCH=$(ARCH)
	@echo "$(GREEN)[KERNEL]$(RESET) Kernel build complete."

# ==============================================================================
# Build modules
# ==============================================================================
modules: build
	@echo "$(BLUE)[KERNEL]$(RESET) Building kernel modules..."
	@cd $(BUILD_DIR)/linux-$(KERNEL_VERSION) && \
		make -j$(NPROC) ARCH=$(ARCH) modules
	@echo "$(GREEN)[KERNEL]$(RESET) Module build complete."

# ==============================================================================
# Package kernel
# ==============================================================================
package: modules
	@echo "$(BLUE)[KERNEL]$(RESET) Packaging kernel..."
	@mkdir -p $(PKG_DIR)
	@cd $(BUILD_DIR)/linux-$(KERNEL_VERSION) && \
		make INSTALL_MOD_PATH=$(PKG_DIR) modules_install && \
		cp arch/$(ARCH)/boot/bzImage $(PKG_DIR)/vmlinuz-orionos && \
		cp System.map $(PKG_DIR)/System.map-orionos && \
		cp .config $(PKG_DIR)/config-orionos
	@echo "$(GREEN)[KERNEL]$(RESET) Package created in $(PKG_DIR)"

# ==============================================================================
# Install kernel to system
# ==============================================================================
install: package
	@echo "$(BLUE)[KERNEL]$(RESET) Installing kernel..."
	@cd $(BUILD_DIR)/linux-$(KERNEL_VERSION) && \
		make modules_install ARCH=$(ARCH) && \
		cp arch/$(ARCH)/boot/bzImage /boot/vmlinuz-orionos && \
		cp System.map /boot/System.map-orionos && \
		cp .config /boot/config-orionos && \
		mkinitcpio -k $(KERNEL_VERSION)-orionos -g /boot/initramfs-orionos.img
	@echo "$(GREEN)[KERNEL]$(RESET) Kernel installed."

# ==============================================================================
# Update GRUB
# ==============================================================================
update-grub:
	@echo "$(BLUE)[KERNEL]$(RESET) Updating GRUB..."
	@grub-mkconfig -o /boot/grub/grub.cfg
	@echo "$(GREEN)[KERNEL]$(RESET) GRUB updated."

# ==============================================================================
# Full install (package + install + update-grub)
# ==============================================================================
install-full: install update-grub

# ==============================================================================
# Clean build artifacts
# ==============================================================================
clean:
	@echo "$(YELLOW)[KERNEL]$(RESET) Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)/linux-$(KERNEL_VERSION)
	@echo "$(YELLOW)[KERNEL]$(RESET) Build directory cleaned."

# ==============================================================================
# Deep clean
# ==============================================================================
distclean: clean
	@echo "$(YELLOW)[KERNEL]$(RESET) Deep cleaning..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(SRC_DIR)
	@echo "$(YELLOW)[KERNEL]$(RESET) All artifacts removed."

# ==============================================================================
# Help
# ==============================================================================
help:
	@echo "$(BLUE)OrionOS Kernel Build - Available Targets:$(RESET)"
	@echo ""
	@echo "  $(GREEN)all$(RESET)            - Full build pipeline"
	@echo "  $(GREEN)download$(RESET)       - Download kernel sources"
	@echo "  $(GREEN)download-patches$(RESET) - Download CachyOS patches"
	@echo "  $(GREEN)extract$(RESET)        - Extract kernel sources"
	@echo "  $(GREEN)patch$(RESET)          - Apply CachyOS patches"
	@echo "  $(GREEN)configure$(RESET)      - Configure kernel"
	@echo "  $(GREEN)build$(RESET)          - Build kernel"
	@echo "  $(GREEN)modules$(RESET)        - Build modules"
	@echo "  $(GREEN)package$(RESET)        - Package built kernel"
	@echo "  $(GREEN)install$(RESET)        - Install to /boot"
	@echo "  $(GREEN)install-full$(RESET)   - Install + update GRUB"
	@echo "  $(GREEN)clean$(RESET)          - Clean build artifacts"
	@echo "  $(GREEN)distclean$(RESET)      - Deep clean everything"
	@echo ""
	@echo "$(BLUE)Variables:$(RESET)"
	@echo "  KERNEL_VERSION  - Kernel version to build (default: $(KERNEL_VERSION))"
	@echo "  BUILD_DIR       - Build directory (default: $(BUILD_DIR))"
	@echo "  ARCH            - Target architecture (default: $(ARCH))"
	@echo "  NPROC           - Parallel jobs (default: $(NPROC))"
