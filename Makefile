# ================================================
# Fab-Agon Emulator Makefile (macOS/Linux/Windows)
# ================================================

SHELL := /bin/sh

# Detect platform
UNAME_S := $(shell uname -s)
OS_WIN  := $(findstring Windows_NT,$(OS))
# MSYS/Git-Bash report "MINGW64_NT-10.0-XXXX" etc; CYGWIN shows CYGWIN_NT-*
IS_MINGW := $(findstring MINGW,$(UNAME_S))
IS_CYGWIN := $(findstring CYGWIN,$(UNAME_S))

# Executable suffix
ifeq ($(OS_WIN),Windows_NT)
  EXE := .exe
else ifneq ($(IS_MINGW),)
  EXE := .exe
else ifneq ($(IS_CYGWIN),)
  EXE := .exe
else
  EXE :=
endif

# Default install prefixes (portable)
# On Windows, default to "$$HOME/.local" so we avoid spaces in "Program Files"
ifeq ($(EXE),.exe)
  PREFIX  ?= $(HOME)/.local
else
  PREFIX  ?= /usr/local
endif

DESTDIR ?=
BINDIR  ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/fab-agon-emulator

# Paths
FIRMWARE_DIR := firmware
VDP_DIR      := src/vdp
EMULATOR_BIN := fab-agon-emulator$(EXE)
CLI_BIN      := agon-cli-emulator$(EXE)

# Phony targets
.PHONY: all check vdp cargo clean vdp-clean cargo-clean depends install install-windows

# --------------------------------
# Default build
# --------------------------------
all: check vdp cargo

# --------------------------------
# Checks
# --------------------------------
check:
	@if [ ! -f ./src/vdp/userspace-vdp-gl/README.md ]; then \
	  echo "Error: no source tree in ./src/vdp/userspace-vdp."; \
	  echo "Maybe you forgot to run: git submodule update --init --recursive"; \
	  echo; exit 1; \
	fi
	@mkdir -p "$(FIRMWARE_DIR)"

# --------------------------------
# VDP Build
# --------------------------------
vdp:
ifeq ($(UNAME_S),Darwin)
	@echo "Building VDP for x86_64..."
	EXTRA_FLAGS="-Wno-c++11-narrowing -arch x86_64" SUFFIX=.x86_64 $(MAKE) -C $(VDP_DIR)
	@echo "Building VDP for arm64..."
	EXTRA_FLAGS="-Wno-c++11-narrowing -arch arm64"  SUFFIX=.arm64  $(MAKE) -C $(VDP_DIR)
	$(MAKE) -C $(VDP_DIR) lipo
	@mkdir -p "$(FIRMWARE_DIR)"
	@find "$(VDP_DIR)" -type f -name "*.so" \
		! -name "*.x86_64.so" ! -name "*.arm64.so" -exec cp -f {} "$(FIRMWARE_DIR)"/ \;
	@# Use c8 VDP for platform firmware also
	@cp -f "$(FIRMWARE_DIR)/vdp_console8.so" "$(FIRMWARE_DIR)/vdp_platform.so"
else
	$(MAKE) -C $(VDP_DIR)
	@mkdir -p "$(FIRMWARE_DIR)"
	@# Copy whatever the VDP produced: prefer .so but accept .dll on Windows builds
	@sh -c 'set -e; \
		for f in $(VDP_DIR)/*.so $(VDP_DIR)/*.dll; do \
			[ -e "$$f" ] && cp -f "$$f" "$(FIRMWARE_DIR)/"; \
		done'
	@# Use c8 VDP for platform firmware also (if present)
	@sh -c 'set -e; \
		if [ -e "$(FIRMWARE_DIR)/vdp_console8.so" ]; then cp -f "$(FIRMWARE_DIR)/vdp_console8.so" "$(FIRMWARE_DIR)/vdp_platform.so"; \
		elif [ -e "$(FIRMWARE_DIR)/vdp_console8.dll" ]; then cp -f "$(FIRMWARE_DIR)/vdp_console8.dll" "$(FIRMWARE_DIR)/vdp_platform.dll"; fi'
endif

depends:
	$(MAKE) -C $(VDP_DIR) depends

# --------------------------------
# Rust Builds
# --------------------------------
cargo:
	# Build the CLI helper first
	cargo build -r --manifest-path=./agon-cli-emulator/Cargo.toml
ifeq ($(EXE),.exe)
	# Windows (MSYS/MinGW/Cygwin)
	set FORCE=1 && cargo build -r
	cp -f "./target/release/fab-agon-emulator$(EXE)" "./$(EMULATOR_BIN)"
else ifeq ($(UNAME_S),Darwin)
	FORCE=1 cargo build -r --target x86_64-apple-darwin
	FORCE=1 cargo build -r --target aarch64-apple-darwin
	lipo -create \
	  -output "./fab-agon-emulator" \
	  "./target/x86_64-apple-darwin/release/fab-agon-emulator" \
	  "./target/aarch64-apple-darwin/release/fab-agon-emulator"
else
	FORCE=1 cargo build -r
	cp -f "./target/release/fab-agon-emulator" "./fab-agon-emulator"
endif

# --------------------------------
# Cleaning
# --------------------------------
vdp-clean:
	@rm -f "$(FIRMWARE_DIR)"/*.so "$(FIRMWARE_DIR)"/*.dll
ifeq ($(UNAME_S),Darwin)
	EXTRA_FLAGS="-Wno-c++11-narrowing -arch x86_64" SUFFIX=.x86_64 $(MAKE) -C $(VDP_DIR) clean
	EXTRA_FLAGS="-Wno-c++11-narrowing -arch arm64"  SUFFIX=.arm64  $(MAKE) -C $(VDP_DIR) clean
else
	$(MAKE) -C $(VDP_DIR) clean
endif

cargo-clean:
	@rm -f "$(EMULATOR_BIN)"
	cargo clean

clean: vdp-clean cargo-clean

# --------------------------------
# Install (portable)
# --------------------------------
# Note: uses POSIX cp/mkdir so it works on macOS, Linux, and MSYS Git-Bash.
install:
	@mkdir -p "$(DESTDIR)$(DATADIR)" "$(DESTDIR)$(BINDIR)"
	@# Firmware: accept both .so and .dll
	@sh -c 'set -e; for f in $(FIRMWARE_DIR)/vdp_*.so $(FIRMWARE_DIR)/vdp_*.dll $(FIRMWARE_DIR)/mos_*.bin $(FIRMWARE_DIR)/mos_*.map; do \
		[ -e "$$f" ] && cp -f "$$f" "$(DESTDIR)$(DATADIR)/"; \
	done'
	@# Binaries: prefer target outputs; fall back to merged binary in repo root
	@sh -c 'set -e; \
		if [ -x "./target/release/fab-agon-emulator$(EXE)" ]; then cp -f "./target/release/fab-agon-emulator$(EXE)" "$(DESTDIR)$(BINDIR)/"; \
		elif [ -x "./fab-agon-emulator$(EXE)" ]; then cp -f "./fab-agon-emulator$(EXE)" "$(DESTDIR)$(BINDIR)/"; fi'
	@sh -c 'set -e; \
		if [ -x "./target/release/agon-cli-emulator$(EXE)" ]; then cp -f "./target/release/agon-cli-emulator$(EXE)" "$(DESTDIR)$(BINDIR)/"; \
		elif [ -x "./agon-cli-emulator$(EXE)" ]; then cp -f "./agon-cli-emulator$(EXE)" "$(DESTDIR)$(BINDIR)/"; fi'
	@echo "Installed to $(DESTDIR)$(PREFIX)"

# Convenience alias for Windows users who insist on DESTDIR gymnastics
install-windows: install
