#!/bin/bash
# create-dmg.sh - Build and package Free Up My Mac as a DMG

set -e

# Configuration
APP_NAME="Free Up My Mac"
SCHEME="free-up-my-mac"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
VOLUME_NAME="${APP_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${ROOT_DIR}/free-up-my-mac"

echo "=== Building ${APP_NAME} ==="
echo "Root directory: ${ROOT_DIR}"
echo "Project directory: ${PROJECT_DIR}"

# Navigate to project directory
cd "${PROJECT_DIR}"

# Clean previous build
echo "Cleaning previous build..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build archive
echo "Building archive..."
xcodebuild archive \
    -scheme "${SCHEME}" \
    -archivePath "${ARCHIVE_PATH}" \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E "^(Building|Linking|Signing|Archive|error:|warning:)" || true

# Check if archive was created
if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo "Error: Archive was not created"
    exit 1
fi

# Export app from archive
echo "Exporting app..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${ROOT_DIR}/scripts/ExportOptions.plist" \
    | grep -E "^(Exporting|error:|warning:)" || true

# Find the exported app
APP_PATH=$(find "${EXPORT_PATH}" -name "*.app" -type d | head -n 1)

if [ -z "${APP_PATH}" ]; then
    echo "Error: Exported app not found"
    exit 1
fi

echo "Found app at: ${APP_PATH}"

# Create temporary DMG directory
DMG_TEMP="${BUILD_DIR}/dmg-temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copy app to temp directory
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create Applications symlink for drag-to-install
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
echo "Creating DMG..."
rm -f "${DMG_PATH}"

# Create DMG using hdiutil
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# Cleanup
rm -rf "${DMG_TEMP}"
rm -rf "${ARCHIVE_PATH}"

echo ""
echo "=== Build Complete ==="
echo "DMG created at: ${DMG_PATH}"
echo ""

# Print DMG info
ls -lh "${DMG_PATH}"

echo ""
echo "To install:"
echo "1. Open ${DMG_PATH}"
echo "2. Drag '${APP_NAME}' to the Applications folder"
