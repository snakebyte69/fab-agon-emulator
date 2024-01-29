#CC := GCC-13
#CXX := G++-13
COMPILER := $(filter g++ clang,$(shell $(CXX) --version))

#CXXFLAGS = -Wall -F /Library/Frameworks
#LDFLAGS = -framework SDL2 -F /Library/Frameworks -I /Library/Frameworks/SDL2.framework/Headers

UNAME_S := $(shell uname)
ARCH := $(shell uname -m)

DYLD_LIBRARY_PATH := ~/Documents/Github/tomm/fab-agon-emulator/target/x86_64-apple-darwin/release/:$DYLD_LIBRARY_PATH

all: display-compiler check vdp cargo

display-compiler:
	@echo "-----------------------------"
	@echo "| Chosen C         : $(CC)"
	@echo "| Chosen C++       : $(CXX)"
	@echo "| Chosen Compiler  : $(COMPILER)"
	@echo "| Windows          : $(OS)"
	@echo "-----------------------------"
	@echo
	$(info )
	$(info ----------------------------)
	$(info | Operating System: $(UNAME_S))
	$(info ----------------------------)
	$(info | Architecture: $(ARCH))

check:
ifeq ($(OS),Windows_NT)
	@if not exist ./src/vdp/userspace-vdp-gl/README.md ( echo Error: no source tree in ./src/vdp/userspace-vdp. && echo Maybe you forgot to run: git submodule update --init && exit /b 1 )
else
	@if [ ! -f ./src/vdp/userspace-vdp-gl/README.md ]; then echo "Error: no source tree in ./src/vdp/userspace-vdp."; echo "Maybe you forgot to run: git submodule update --init"; echo; exit 1; fi
endif

vdp:
ifeq ($(UNAME_S),Darwin)
    ifeq ($(ARCH),x86_64)
		EXTRA_FLAGS="-Wno-c++11-narrowing -arch x86_64" SUFFIX=.x86_64 $(MAKE) -C src/vdp
		$(foreach file, $(wildcard src/vdp/*.x86_64.so), lipo -create -output src/vdp/$(notdir $(file:.x86_64.so=.so)) $(file) src/vdp/$(notdir $(file:.x86_64.so=.arm64.so));)
    else ifeq ($(ARCH),aarch64)
		EXTRA_FLAGS="-Wno-c++11-narrowing -arch arm64" SUFFIX=.arm64 $(MAKE) -C src/vdp
		$(foreach file, $(wildcard src/vdp/*.x86_64.so), lipo -create -output src/vdp/$(notdir $(file:.x86_64.so=.so)) $(file) src/vdp/$(notdir $(file:.x86_64.so=.arm64.so));)
    else # Assume Linux
		$(error Unknown architecture: $(ARCH))
		$(MAKE) -C src/vdp
    endif
endif
	cp src/vdp/*.so firmware/

cargo:
ifeq ($(OS),Windows_NT)
	set FORCE=1 && cargo build -r
	cp ./target/release/fab-agon-emulator.exe
endif
ifeq ($(UNAME_S),Darwin)
    ifeq ($(ARCH),x86_64)
	    FORCE=1 cargo build -r --target=x86_64-apple-darwin
	    lipo -create -output ./fab-agon-emulator ./target/x86_64-apple-darwin/release/fab-agon-emulator
    else ifeq ($(ARCH),aarch64)
	    FORCE=1 cargo build -r --target=aarch64-apple-darwin
	    lipo -create -output ./fab-agon-emulator ./target/aarch64-apple-darwin/release/fab-agon-emulator
    else # Assume Linux
	    $(error Unknown architecture: $(ARCH))
	    FORCE=1 cargo build -r
	    cp ./target/release/fab-agon-emulator
    endif
endif

ifeq ($(ARCH),x86_64)
	cp firmware/vdp_console8.x86_64.so firmware/vdp_console8.so
else ifeq ($(ARCH),aarch64)
	cp firmware/vdp_console8.arm64.so firmware/vdp_console8.so
endif

vdp-clean:
	rm -f firmware/*.so
	$(MAKE) -C src/vdp clean

cargo-clean:
	cargo clean

clean: vdp-clean cargo-clean

depends:
	$(MAKE) -C src/vdp depends