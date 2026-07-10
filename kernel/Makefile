# =============================================================================
# OrionOS Custom Kernel Build System
# Based on Linux with CachyOS performance optimizations
# =============================================================================

# Configuration
KERNEL_VERSION ?= 6.11
KERNEL_RELEASE ?= 1
BUILD_DIR ?= $(PWD)/build
SOURCE_DIR ?= $(PWD)/sources
PATCH_DIR ?= $(PWD)/patches
CONFIG_DIR ?= $(PWD)/config
JOBS ?= $(shell nproc)
ARCH ?= x86_64

# Kernel source
KERNEL_URL = https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$(KERNEL_VERSION).tar.xz
KERNEL_SOURCE = $(SOURCE_DIR)/linux-$(KERNEL_VERSION)
KERNEL_TARBALL = $(SOURCE_DIR)/linux-$(KERNEL_VERSION).tar.xz

# Output
KERNEL_PACKAGE = $(BUILD_DIR)/linux-orionos-$(KERNEL_VERSION).$(KERNEL_RELEASE)-$(ARCH).pkg.tar.zst
HEADERS_PACKAGE = $(BUILD_DIR)/linux-orionos-headers-$(KERNEL_VERSION).$(KERNEL_RELEASE)-$(ARCH).pkg.tar.zst

.PHONY: all download extract patch config build package clean

all: download extract patch config build package

# Download kernel source
download: $(KERNEL_TARBALL)

$(KERNEL_TARBALL):
	@echo "[KERNEL] Downloading Linux $(KERNEL_VERSION)..."
	@mkdir -p $(SOURCE_DIR)
	@curl -L -o $@.tmp $(KERNEL_URL)
	@mv $@.tmp $@

# Extract kernel source
extract: $(KERNEL_SOURCE)/Makefile

$(KERNEL_SOURCE)/Makefile: $(KERNEL_TARBALL)
	@echo "[KERNEL] Extracting kernel source..."
	@mkdir -p $(KERNEL_SOURCE)
	@tar -xf $< -C $(SOURCE_DIR) --strip-components=0
	@touch $@

# Apply patches
patch: $(KERNEL_SOURCE)/.patched

$(KERNEL_SOURCE)/.patched: extract
	@echo "[KERNEL] Applying OrionOS patches..."
	@cd $(KERNEL_SOURCE) && \
	for patch in $(PATCH_DIR)/*.patch; do \
		if [ -f "$$patch" ]; then \
			echo "  Applying: $$(basename $$patch)"; \
			patch -p1 < "$$patch" || true; \
		fi \
	done
	@# Apply CachyOS BORE scheduler patch
	@if [ -f $(PATCH_DIR)/cachyos/0001-bore-scheduler.patch ]; then \
		cd $(KERNEL_SOURCE) && patch -p1 < $(PATCH_DIR)/cachyos/0001-bore-scheduler.patch; \
	fi
	@# Apply CachyOS CPU optimizations
	@if [ -f $(PATCH_DIR)/cachyos/0002-cpu-optimizations.patch ]; then \
		cd $(KERNEL_SOURCE) && patch -p1 < $(PATCH_DIR)/cachyos/0002-cpu-optimizations.patch; \
	fi
	@# Apply CachyOS memory management patches
	@if [ -f $(PATCH_DIR)/cachyos/0003-memory-optimizations.patch ]; then \
		cd $(KERNEL_SOURCE) && patch -p1 < $(PATCH_DIR)/cachyos/0003-memory-optimizations.patch; \
	fi
	@# Apply CachyOS io_uring optimizations
	@if [ -f $(PATCH_DIR)/cachyos/0004-iouring-optimizations.patch ]; then \
		cd $(KERNEL_SOURCE) && patch -p1 < $(PATCH_DIR)/cachyos/0004-iouring-optimizations.patch; \
	fi
	@# Apply gaming latency patches
	@if [ -f $(PATCH_DIR)/gaming/0001-gaming-latency.patch ]; then \
		cd $(KERNEL_SOURCE) && patch -p1 < $(PATCH_DIR)/gaming/0001-gaming-latency.patch; \
	fi
	@# Apply desktop responsiveness patches
	@if [ -f $(PATCH_DIR)/desktop/0001-desktop-responsiveness.patch ]; then \
		cd $(KERNEL_SOURCE) && patch -p1 < $(PATCH_DIR)/desktop/0001-desktop-responsiveness.patch; \
	fi
	@touch $@

# Configure kernel
config: $(KERNEL_SOURCE)/.config

$(KERNEL_SOURCE)/.config: patch
	@echo "[KERNEL] Configuring kernel..."
	@cp $(CONFIG_DIR)/orionos-kernel.config $@
	@cd $(KERNEL_SOURCE) && make olddefconfig

# Build kernel
build: $(KERNEL_SOURCE)/arch/$(ARCH)/boot/bzImage

$(KERNEL_SOURCE)/arch/$(ARCH)/boot/bzImage: config
	@echo "[KERNEL] Building kernel with $(JOBS) jobs..."
	@cd $(KERNEL_SOURCE) && make -j$(JOBS)
	@cd $(KERNEL_SOURCE) && make -j$(JOBS) modules

# Package kernel
package: $(KERNEL_PACKAGE) $(HEADERS_PACKAGE)

$(KERNEL_PACKAGE): build
	@echo "[KERNEL] Creating kernel package..."
	@mkdir -p $(BUILD_DIR)/pkg/{boot,usr/lib/modules,usr/lib/firmware}
	@cd $(KERNEL_SOURCE) && \
		cp arch/$(ARCH)/boot/bzImage $(BUILD_DIR)/pkg/boot/vmlinuz-linux-orionos && \
		make modules_install INSTALL_MOD_PATH=$(BUILD_DIR)/pkg/usr
	@# Create initramfs
	@cd $(KERNEL_SOURCE) && mkinitcpio -k $(KERNEL_VERSION)-orionos -g $(BUILD_DIR)/pkg/boot/initramfs-linux-orionos.img
	@# Create PKGBUILD and build
	@mkdir -p $(BUILD_DIR)/pkg-build
	@cat > $(BUILD_DIR)/pkg-build/PKGBUILD << 'PKGBUILD_EOF'
pkgname=linux-orionos
pkgver=$(KERNEL_VERSION)
pkgrel=$(KERNEL_RELEASE)
arch=('x86_64')
description='OrionOS custom kernel with performance optimizations'

package() {
    cp -r $(BUILD_DIR)/pkg/* "${pkgdir}/"
}
PKGBUILD_EOF
	@cd $(BUILD_DIR)/pkg-build && makepkg -f --skipchecksums

$(HEADERS_PACKAGE): build
	@echo "[KERNEL] Creating headers package..."
	@mkdir -p $(BUILD_DIR)/hdr/usr/src/linux-$(KERNEL_VERSION)-orionos
	@cd $(KERNEL_SOURCE) && \
		make headers_install INSTALL_HDR_PATH=$(BUILD_DIR)/hdr/usr/src/linux-$(KERNEL_VERSION)-orionos
	@# Create headers package
	@mkdir -p $(BUILD_DIR)/hdr-build
	@cat > $(BUILD_DIR)/hdr-build/PKGBUILD << 'HDRBUILD_EOF'
pkgname=linux-orionos-headers
pkgver=$(KERNEL_VERSION)
pkgrel=$(KERNEL_RELEASE)
arch=('x86_64')
description='OrionOS kernel headers'

package() {
    cp -r $(BUILD_DIR)/hdr/* "${pkgdir}/"
}
HDRBUILD_EOF
	@cd $(BUILD_DIR)/hdr-build && makepkg -f --skipchecksums

clean:
	@rm -rf $(BUILD_DIR) $(SOURCE_DIR)
	@echo "[KERNEL] Build artifacts cleaned."
