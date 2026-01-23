# Free Up My Mac - Duplicate File Finder

## Overview

A native macOS application that helps users find and remove duplicate files to free up storage space. The app identifies duplicates based on file content (not metadata), ensuring that identical files saved at different times or with different names are detected.

## Project Status

- [x] Phase 1: Project Setup & Core Architecture ✅
- [x] Phase 2: File Scanning Engine ✅
- [x] Phase 3: User Interface ✅
- [ ] Phase 4: Duplicate Detection Algorithm  ← CURRENT
- [ ] Phase 5: File Management & Deletion
- [ ] Phase 6: History & Sharing Features
- [ ] Phase 7: Polish & Testing

## Development Approach

This project follows **Test-Driven Development (TDD)**:
1. Write failing tests first
2. Implement minimum code to pass tests
3. Refactor while keeping tests green
4. Repeat for each feature

---

## Technical Specifications

### Platform & Distribution

| Attribute | Value |
|-----------|-------|
| Platform | macOS 13.0+ (Ventura and later) |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Distribution | Direct distribution (DMG/ZIP) |
| Sandboxing | Non-sandboxed (full file system access with user permission) |

### Core Features

1. **Directory Selection**
   - Allow users to select specific directories to scan
   - Support scanning entire user home directory
   - Support drag-and-drop of folders into the app
   - Remember recently scanned directories

2. **Duplicate Detection**
   - Content-based comparison (ignore metadata like creation date, modification date)
   - Detect identical files regardless of filename
   - Group duplicates together showing all copies

3. **Results Display**
   - Group duplicates by content (all copies shown together)
   - Sort/filter groups by potential space savings
   - Show file paths, sizes, and modification dates
   - Display total potential storage savings
   - Display per-group storage savings

4. **File Preview**
   - Integrate macOS Quick Look for file preview
   - Support previewing images, PDFs, documents, videos, etc.
   - Press Space or click preview button to view file

5. **File Deletion**
   - Select individual duplicate groups for deletion
   - Select all duplicates at once
   - Smart selection: automatically keep one copy, select others for deletion
   - Move files to Trash (recoverable)
   - Show confirmation before deletion

6. **Progress Indication**
   - Detailed progress bar during scan
   - Show current folder being scanned
   - Show number of files scanned
   - Show elapsed time
   - Allow cancellation of scan

7. **Savings History & Sharing**
   - Track history of all cleanup sessions
   - Record date, files deleted, and space freed for each session
   - Show cumulative total space saved across all sessions
   - Display history in a dedicated view with timeline
   - Share savings achievements via social media, messages, or copy link
   - Generate shareable cards/images showing space saved
   - Include app download link in shared content for viral growth

---

## Performance Architecture

### Multi-Stage Duplicate Detection Algorithm

The app uses a multi-stage filtering approach to maximize performance. This avoids computing expensive hashes for every file.

```
Stage 1: Size Grouping (Fast)
├── Group all files by exact file size
├── Discard groups with only 1 file (no duplicates possible)
└── Pass remaining groups to Stage 2

Stage 2: Partial Hash (Medium)
├── For each size group, compute partial hash
│   ├── Hash first 4KB of file
│   ├── Hash last 4KB of file
│   └── Combine into partial hash
├── Group files by (size + partial hash)
├── Discard groups with only 1 file
└── Pass remaining groups to Stage 3

Stage 3: Full Content Hash (Slower but only for candidates)
├── Compute full xxHash64 of entire file content
├── Group files by (size + full hash)
├── Discard groups with only 1 file
└── Return duplicate groups to UI
```

### Why This Approach?

| Stage | Speed | Files Processed |
|-------|-------|-----------------|
| Size grouping | ~100,000+ files/sec | All files |
| Partial hash | ~10,000+ files/sec | ~5-10% of files |
| Full hash | Depends on file size | ~1-2% of files |

Most files are eliminated at Stage 1 (different sizes), making the overall process very fast.

### Hashing Algorithm

- **Algorithm**: xxHash64
- **Why**: Extremely fast (10+ GB/s on modern hardware), suitable for duplicate detection
- **Note**: Not cryptographically secure, but collision probability is negligible for duplicate detection

### Concurrency Model

```swift
// Parallel file scanning with controlled concurrency
- Use Swift Concurrency (async/await, TaskGroup)
- Limit concurrent file reads to prevent I/O saturation
- Recommended: 4-8 concurrent file operations
- Use background quality-of-service for non-blocking UI
```

### Memory Management

- Stream large files instead of loading entirely into memory
- Process files in batches to limit memory usage
- Release file handles promptly after hashing
- Target: Handle 1M+ files without excessive memory usage

---

## File Filtering Rules

### Minimum File Size
- **Threshold**: 1 KB (1,024 bytes)
- Files smaller than this are ignored (config files, empty files, etc.)

### Excluded by Default

```
System Directories:
- /System
- /Library (except ~/Library)
- /private
- /usr
- /bin
- /sbin
- /var
- /.vol
- /Applications (system apps)

Hidden Items:
- Files/folders starting with "."
- .DS_Store, .localized, .Spotlight-V100, etc.

App Bundles:
- *.app directories (scanned as single item or skipped)
- *.framework
- *.bundle

Special Files:
- Symbolic links (to avoid counting same file twice)
- Aliases
- Hard links (detect and handle appropriately)
```

### Included
- All user files in selected directories
- Documents, images, videos, audio, archives, etc.
- No file type restrictions

---

## User Interface Design

### Main Window Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Free Up My Mac                           [History] [─][□][×]│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Select folders to scan                              │   │
│  │  ┌───────────────────────────────────┐              │   │
│  │  │ 📁 ~/Documents                 [×] │              │   │
│  │  │ 📁 ~/Downloads                 [×] │              │   │
│  │  └───────────────────────────────────┘              │   │
│  │         [+ Add Folder]  [Scan Home Directory]       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  💾 Total space saved: 12.4 GB (across 8 cleanups)   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│                    [ 🔍 Start Scan ]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Scanning Progress View

```
┌─────────────────────────────────────────────────────────────┐
│  Scanning for duplicates...                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ████████████████░░░░░░░░░░░░░░  45%                       │
│                                                             │
│  📁 Current: ~/Documents/Projects/Photos                    │
│  📄 Files scanned: 45,231                                   │
│  ⏱️  Elapsed: 00:01:23                                      │
│  🔍 Potential duplicates found: 1,247                       │
│                                                             │
│                    [ Cancel Scan ]                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Results View

```
┌─────────────────────────────────────────────────────────────┐
│  Scan Complete                              [New Scan]      │
├─────────────────────────────────────────────────────────────┤
│  Found 156 duplicate groups • 2.4 GB can be freed          │
│                                                             │
│  Sort by: [Size ▼]  Filter: [All Types]  [Select All Dups] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Group 1: 3 copies • 524 MB each • 1.05 GB savings ───┐ │
│  │ ☑️ 📄 ~/Downloads/movie.mp4         524 MB  2024-01-15 │ │
│  │ ☐ 📄 ~/Videos/movie.mp4             524 MB  2024-01-10 │ │
│  │ ☑️ 📄 ~/Desktop/movie (1).mp4       524 MB  2024-01-20 │ │
│  │                                      [Preview] [Open]  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─ Group 2: 2 copies • 15 MB each • 15 MB savings ──────┐ │
│  │ ☑️ 📄 ~/Documents/report.pdf        15 MB   2024-01-12 │ │
│  │ ☐ 📄 ~/Desktop/report_final.pdf     15 MB   2024-01-18 │ │
│  │                                      [Preview] [Open]  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  [More groups...]                                           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Selected: 157 files • 1.8 GB    [ 🗑️ Move to Trash ]      │
└─────────────────────────────────────────────────────────────┘
```

### History View

```
┌─────────────────────────────────────────────────────────────┐
│  Savings History                                   [Share]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         🎉 Total Space Saved: 12.4 GB               │   │
│  │            across 8 cleanup sessions                 │   │
│  │                                                      │   │
│  │    [📤 Share Achievement]  [📋 Copy Stats]          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  📅 Cleanup History                                         │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  Jan 22, 2025                                              │
│  └─ Cleaned 45 duplicate files • Saved 2.1 GB              │
│     Folders: ~/Downloads, ~/Documents                       │
│                                                             │
│  Jan 15, 2025                                              │
│  └─ Cleaned 128 duplicate files • Saved 4.8 GB             │
│     Folders: ~/Pictures, ~/Videos                          │
│                                                             │
│  Jan 8, 2025                                               │
│  └─ Cleaned 23 duplicate files • Saved 890 MB              │
│     Folders: ~/Desktop                                      │
│                                                             │
│  Dec 28, 2024                                              │
│  └─ Cleaned 67 duplicate files • Saved 1.2 GB              │
│     Folders: Home Directory                                 │
│                                                             │
│  [View all history...]                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Share Card (Generated Image)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    🧹 Free Up My Mac                        │
│                                                             │
│              I just freed up 2.1 GB                         │
│           by removing duplicate files!                      │
│                                                             │
│         ┌─────────────────────────────────┐                │
│         │   📊 My Total Savings: 12.4 GB  │                │
│         │   🗂️  Files Cleaned: 263        │                │
│         │   ✨ Cleanup Sessions: 8        │                │
│         └─────────────────────────────────┘                │
│                                                             │
│          Download free: freeupmymac.app                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Models

### Core Types

```swift
/// Represents a single file in the system
struct ScannedFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let size: Int64
    let modificationDate: Date
    var partialHash: UInt64?
    var fullHash: UInt64?
}

/// A group of duplicate files (same content)
struct DuplicateGroup: Identifiable {
    let id: UUID
    let hash: UInt64
    let fileSize: Int64
    var files: [ScannedFile]

    var duplicateCount: Int { files.count }
    var potentialSavings: Int64 { fileSize * Int64(files.count - 1) }
}

/// Overall scan results
struct ScanResult {
    let scannedDirectories: [URL]
    let totalFilesScanned: Int
    let totalSizeScanned: Int64
    let duplicateGroups: [DuplicateGroup]
    let scanDuration: TimeInterval

    var totalDuplicateFiles: Int
    var totalPotentialSavings: Int64
}

/// Scan progress for UI updates
struct ScanProgress {
    let phase: ScanPhase
    let currentDirectory: String
    let filesScanned: Int
    let duplicatesFound: Int
    let progress: Double // 0.0 to 1.0
    let elapsedTime: TimeInterval
}

enum ScanPhase {
    case indexing
    case sizingGrouping
    case partialHashing
    case fullHashing
    case complete
}

/// A single cleanup session record for history
struct CleanupSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let filesDeleted: Int
    let spaceSaved: Int64  // in bytes
    let scannedDirectories: [String]  // paths as strings for Codable
}

/// Aggregated savings statistics
struct SavingsStats: Codable {
    var totalSpaceSaved: Int64
    var totalFilesDeleted: Int
    var totalSessions: Int
    var sessions: [CleanupSession]

    var formattedTotalSaved: String {
        ByteCountFormatter.string(fromByteCount: totalSpaceSaved, countStyle: .file)
    }
}
```

### History Persistence

```swift
/// Manages saving/loading cleanup history
class HistoryManager {
    private let historyFileURL: URL  // ~/Library/Application Support/FreeUpMyMac/history.json

    func addSession(_ session: CleanupSession)
    func loadHistory() -> SavingsStats
    func clearHistory()
    func exportHistory() -> Data  // JSON export
}
```

---

## Sharing Feature

### Share Options

1. **Share Sheet Integration**
   - Native macOS share sheet
   - Messages, Mail, AirDrop, social media
   - Copy to clipboard

2. **Shareable Content Types**
   - **Text**: "I just freed up 2.1 GB with Free Up My Mac! Total savings: 12.4 GB. Download free: [link]"
   - **Image**: Generated share card with stats (PNG)
   - **Link**: Direct download link to app

3. **Share Card Generation**
   - Use SwiftUI to render share card view
   - Export as PNG image using ImageRenderer
   - Include: latest savings, total savings, cleanup count, app branding

### Implementation

```swift
struct ShareContent {
    let text: String
    let image: NSImage?
    let url: URL?

    static func generate(from stats: SavingsStats, latestSession: CleanupSession?) -> ShareContent
}

// Share card view rendered to image
struct ShareCardView: View {
    let stats: SavingsStats
    let latestSavings: Int64?
    // ... renders the branded share card
}

// Generate shareable image
func generateShareImage(stats: SavingsStats) -> NSImage {
    let renderer = ImageRenderer(content: ShareCardView(stats: stats))
    renderer.scale = 2.0  // Retina
    return renderer.nsImage!
}
```

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ MainView │  │ScanView  │  │ResultView│  │HistoryView│  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     View Models                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              ScanViewModel (@Observable)              │  │
│  │  - scanState, progress, results                      │  │
│  │  - startScan(), cancelScan(), deleteFiles()          │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            HistoryViewModel (@Observable)             │  │
│  │  - savingsStats, sessions                            │  │
│  │  - recordCleanup(), generateShareContent()           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Services                               │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │ ScannerService │  │ HasherService  │  │ FileService  │  │
│  │ - enumerate    │  │ - partialHash  │  │ - moveToTrash│  │
│  │ - filter       │  │ - fullHash     │  │ - getMetadata│  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
│  ┌────────────────┐  ┌────────────────┐                    │
│  │HistoryManager  │  │ ShareService   │                    │
│  │ - persist      │  │ - generateCard │                    │
│  │ - load/save    │  │ - shareSheet   │                    │
│  └────────────────┘  └────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   External Dependencies                     │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │    xxHash      │  │   FileManager  │  │  QuickLook   │  │
│  │   (Swift pkg)  │  │    (macOS)     │  │   (macOS)    │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Files Structure

```
FreeUpMyMac/
├── App/
│   └── FreeUpMyMacApp.swift          # App entry point
├── Views/
│   ├── MainView.swift                # Main window with folder selection
│   ├── ScanProgressView.swift        # Progress during scanning
│   ├── ResultsView.swift             # Display duplicate groups
│   ├── DuplicateGroupView.swift      # Single group of duplicates
│   ├── FileRowView.swift             # Individual file row
│   ├── HistoryView.swift             # Savings history timeline
│   └── ShareCardView.swift           # Shareable achievement card
├── ViewModels/
│   ├── ScanViewModel.swift           # Scan state management
│   └── HistoryViewModel.swift        # History & sharing logic
├── Services/
│   ├── FileScannerService.swift      # Directory enumeration
│   ├── DuplicateDetectorService.swift # Multi-stage detection algorithm
│   ├── FileHasherService.swift       # xxHash implementation
│   ├── FileOperationService.swift    # Delete/trash operations
│   ├── HistoryManager.swift          # Persist cleanup history
│   └── ShareService.swift            # Generate & share content
├── Models/
│   ├── ScannedFile.swift
│   ├── DuplicateGroup.swift
│   ├── ScanResult.swift
│   └── CleanupSession.swift
├── Utilities/
│   ├── FileFilters.swift             # Exclusion rules
│   └── ByteFormatter.swift           # Size formatting
└── Resources/
    └── Assets.xcassets
```

---

## Permissions & Security

### Required Entitlements

```xml
<!-- FreeUpMyMac.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Permission Flow

1. **First Launch**: App explains why file access is needed
2. **Folder Selection**: User selects folders via NSOpenPanel (grants access)
3. **Full Disk Access**: For scanning outside selected folders, guide user to System Preferences
4. **Security Bookmarks**: Store access permissions for future sessions

---

## Data Storage

### History Storage Location
```
~/Library/Application Support/FreeUpMyMac/
├── history.json          # Cleanup session history
└── preferences.plist     # User preferences (optional)
```

### History JSON Schema
```json
{
  "totalSpaceSaved": 13312000000,
  "totalFilesDeleted": 263,
  "totalSessions": 8,
  "sessions": [
    {
      "id": "uuid-string",
      "date": "2025-01-22T10:30:00Z",
      "filesDeleted": 45,
      "spaceSaved": 2254857830,
      "scannedDirectories": ["~/Downloads", "~/Documents"]
    }
  ]
}
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [xxHash-Swift](https://github.com/daisuke-t-jp/xxHash-Swift) | ~> 1.0 | Fast non-cryptographic hashing |

---

## Future Enhancements (Post-MVP)

These features are not in scope for the initial release but could be added later:

- [ ] Similar image detection (perceptual hashing)
- [ ] Duplicate folder detection
- [ ] Scheduled automatic scans
- [ ] Export results to CSV/JSON
- [ ] Dark mode / light mode toggle
- [ ] Localization support
- [ ] Menu bar quick access
- [ ] Smart keep suggestions (keep newest, keep in preferred folder)
- [ ] Ignore list (never flag certain files/folders as duplicates)
- [ ] Undo delete (beyond Trash recovery)
- [ ] Leaderboard / community stats (opt-in)
- [ ] Achievements and badges for milestones

---

## Development Phases

### Phase 1: Project Setup & Core Architecture
- Create Xcode project with SwiftUI
- Set up project structure
- Add xxHash dependency
- Configure entitlements for file access
- Create basic data models

### Phase 2: File Scanning Engine
- Implement directory enumeration
- Add file filtering (size, hidden files, system directories)
- Handle permissions and errors gracefully
- Add progress reporting

### Phase 3: User Interface
- Build main window with folder selection
- Create scan progress view
- Build results view with duplicate groups
- Add Quick Look preview integration
- Implement file selection UI

### Phase 4: Duplicate Detection Algorithm
- Implement Stage 1: Size grouping
- Implement Stage 2: Partial hashing
- Implement Stage 3: Full content hashing
- Add concurrency for performance
- Test with large file sets

### Phase 5: File Management & Deletion
- Implement move to Trash functionality
- Add confirmation dialogs
- Update UI after deletion
- Handle deletion errors

### Phase 6: History & Sharing Features
- Implement HistoryManager for persistence
- Build HistoryView with timeline
- Create ShareCardView for visual sharing
- Integrate with macOS share sheet
- Record cleanup sessions automatically

### Phase 7: Polish & Testing
- Performance optimization
- Error handling improvements
- UI polish and animations
- Testing with various file types and sizes
- Create DMG for distribution

---

## Success Metrics

- Scan 100,000 files in under 60 seconds (on SSD)
- Handle 1TB+ of files without memory issues
- Correctly identify all true duplicates (no false negatives)
- Zero false positives (files flagged as duplicates that aren't)
- Responsive UI throughout scanning (no freezing)
- History persists correctly across app restarts
- Share cards render correctly and look professional
