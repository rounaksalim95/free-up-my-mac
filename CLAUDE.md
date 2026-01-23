# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Free Up My Mac is a native macOS application (Swift/SwiftUI) that helps users find and remove duplicate files using content-based detection with a multi-stage filtering algorithm.

## Build & Test Commands

```bash
# Build
xcodebuild build -scheme free-up-my-mac

# Run all tests
xcodebuild test -scheme free-up-my-mac

# Clean
xcodebuild clean -scheme free-up-my-mac
```

## Architecture

**Layered structure with actor-based concurrency:**

```
SwiftUI Views → ViewModels (@Observable) → Services (actors) → Models (Sendable structs)
```

### Services (all are `actor` types)
- **FileScannerService**: Directory enumeration with filtering (implemented)
- **DuplicateDetectorService**: 3-stage duplicate detection - size grouping → partial hash → full hash (stub)
- **FileHasherService**: xxHash64 computation for partial/full file hashing (stub)
- **FileOperationService**: Trash/delete operations (stub)
- **HistoryManager**: UserDefaults persistence (stub)
- **ShareService**: Report generation (stub)

### Duplicate Detection Algorithm
1. **Stage 1**: Group files by exact size
2. **Stage 2**: Compute partial hash (first/last 4KB) for size-matched files
3. **Stage 3**: Compute full xxHash64 for partial-hash matches

### Key Models
- `ScannedFile`: File metadata + hashes
- `DuplicateGroup`: Group of duplicate files
- `ScanProgress`: Phase tracking with `ScanPhase` enum (idle, enumerating, groupingBySize, computingPartialHashes, computingFullHashes, findingDuplicates, completed, cancelled, failed)

## Conventions

- **TDD approach**: Write failing tests first, then implement. All new functionality should have corresponding tests.
- **Concurrency**: All services are `actor` types; all models conform to `Sendable`
- **Progress callbacks**: Use `@Sendable` closures for real-time UI updates
- **File paths**: Always use `URL` type, never String paths
- **Testing**: Swift Testing framework (`@Suite`, `@Test` macros), not XCTest
- **Test helpers**: `TestDirectory` struct in TestHelpers.swift for temporary file fixtures

## File Filtering Rules

Configured in `FileFilters.swift`:
- Minimum size: 1KB
- Excludes: hidden files, `.git`, `node_modules`, `.Trash`, system paths (`/Library`, `/System`)
- Skips symbolic links and `.app` bundle contents

## Dependencies

- **xxHash-Swift** (v1.1.1): Fast non-cryptographic hashing (~10+ GB/s)

## Development Notes

- macOS 13.0+ target
- Non-sandboxed (full file system access via user selection)
- Progress updates batched every 100 files
- Use `Task.yield()` every 50 files during enumeration for UI responsiveness
- See `SPEC.md` for complete technical specification
