.PHONY: build build-debug install uninstall clean engine-test

# Build Mavro.app (Apple Silicon, release)
build:
	@bash scripts/build.sh release

build-debug:
	@bash scripts/build.sh debug

# Build then install into ~/Library/Input Methods
install: build
	@bash scripts/install.sh

uninstall:
	@bash scripts/uninstall.sh

clean:
	rm -rf build/
	cd engine && cargo clean

# Rust engine checks
engine-test:
	cd engine && cargo test
