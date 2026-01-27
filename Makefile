# Makefile for Free Up My Mac

.PHONY: build test clean dmg help

# Project path
PROJECT_DIR = free-up-my-mac

# Default target
help:
	@echo "Free Up My Mac - Build Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build    Build the application (debug)"
	@echo "  release  Build the application (release)"
	@echo "  test     Run all tests"
	@echo "  clean    Clean build artifacts"
	@echo "  dmg      Create distributable DMG"
	@echo "  help     Show this help message"

# Build debug configuration
build:
	@echo "Building Free Up My Mac (Debug)..."
	cd $(PROJECT_DIR) && set -o pipefail && xcodebuild build \
		-scheme free-up-my-mac \
		-configuration Debug \
		| grep -E "^(Building|Linking|Signing|Build|error:|warning:)" || exit 0

# Build release configuration
release:
	@echo "Building Free Up My Mac (Release)..."
	cd $(PROJECT_DIR) && set -o pipefail && xcodebuild build \
		-scheme free-up-my-mac \
		-configuration Release \
		| grep -E "^(Building|Linking|Signing|Build|error:|warning:)" || exit 0

# Run tests
test:
	@echo "Running tests..."
	cd $(PROJECT_DIR) && set -o pipefail && xcodebuild test \
		-scheme free-up-my-mac \
		-destination 'platform=macOS' \
		| grep -E "^(Test|Executed|error:|warning:|✓|✗)"

# Clean build directory
clean:
	@echo "Cleaning build artifacts..."
	cd $(PROJECT_DIR) && xcodebuild clean -scheme free-up-my-mac
	rm -rf build/
	rm -rf $(PROJECT_DIR)/DerivedData/
	@echo "Clean complete."

# Create DMG for distribution
dmg:
	@echo "Creating DMG..."
	./scripts/create-dmg.sh
