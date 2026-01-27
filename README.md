# Free Up My Mac

A native macOS application that helps users find and remove duplicate files to free up storage space. The app identifies duplicates based on file content (not metadata), ensuring that identical files saved at different times or with different names are detected.

## Features

- **Content-based duplicate detection** - Uses a 3-stage algorithm (size grouping → partial hash → full hash) for fast and accurate detection
- **Safe deletion** - Moves duplicates to Trash (recoverable)
- **Quick Look integration** - Preview files before deletion
- **History tracking** - Track your cleanup sessions and total space saved
- **Shareable achievements** - Generate share cards to show off your savings

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+ (for building from source)

## Building from Source

### Using Make (Recommended)

```bash
# Show available commands
make help

# Build debug version
make build

# Build release version
make release

# Run tests
make test

# Clean build artifacts
make clean
```

### Using Xcode

```bash
# Build
cd free-up-my-mac
xcodebuild build -scheme free-up-my-mac

# Run tests
xcodebuild test -scheme free-up-my-mac

# Clean
xcodebuild clean -scheme free-up-my-mac
```

## Creating a Distribution DMG

To create a distributable DMG file for sharing or installation:

```bash
# Using Make
make dmg

# Or run the script directly
./scripts/create-dmg.sh
```

The DMG will be created at `free-up-my-mac/build/Free Up My Mac.dmg`.

### Installing from DMG

1. Open the generated DMG file
2. Drag "Free Up My Mac" to the Applications folder
3. Eject the DMG
4. Launch from Applications

## Project Structure

```
free-up-my-mac/
├── free-up-my-mac/           # Xcode project
│   ├── free-up-my-mac/       # Main app source
│   │   ├── Models/           # Data models
│   │   ├── Views/            # SwiftUI views
│   │   ├── ViewModels/       # Observable view models
│   │   └── Services/         # Business logic (actors)
│   └── free-up-my-macTests/  # Unit tests
├── scripts/                   # Build and distribution scripts
│   ├── create-dmg.sh         # DMG creation script
│   └── ExportOptions.plist   # Xcode export configuration
├── Makefile                   # Build automation
├── SPEC.md                    # Technical specification
└── CLAUDE.md                  # AI assistant instructions
```

## How It Works

The duplicate detection uses a 3-stage filtering algorithm:

1. **Stage 1 - Size Grouping**: Groups files by exact size (very fast, eliminates most files)
2. **Stage 2 - Partial Hash**: Computes hash of first/last 4KB for size-matched files
3. **Stage 3 - Full Hash**: Computes full xxHash64 only for partial-hash matches

This approach is highly efficient - most files are eliminated at Stage 1, and only potential duplicates require full content hashing.

## License

See [LICENSE](LICENSE) for details.
