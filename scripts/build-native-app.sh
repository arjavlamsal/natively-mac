#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Natively Native macOS Application Packaging Script
# Compiles Swift 6 release binary, packages Natively.app bundle, and signs it.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$REPO_ROOT/macos"
DIST_DIR="$REPO_ROOT/build/dist"
APP_NAME="Natively.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME"

echo "==> [1/5] Building NativelyMac in release mode..."
cd "$MACOS_DIR"
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" xcrun swift build -c release --product NativelyMac

RELEASE_BIN="$MACOS_DIR/.build/out/Products/Release/NativelyMac"
if [ ! -f "$RELEASE_BIN" ]; then
    # Fallback to standard release path if .build/out differs
    RELEASE_BIN="$(find "$MACOS_DIR/.build" -type f -name "NativelyMac" -perm +111 2>/dev/null | grep -E "Release|release" | head -n 1 || true)"
fi

if [ -z "$RELEASE_BIN" ] || [ ! -f "$RELEASE_BIN" ]; then
    echo "ERROR: Could not find compiled release binary NativelyMac!"
    exit 1
fi

echo "==> [2/5] Creating application bundle directory structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> [3/5] Installing binary and bundle metadata..."
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/NativelyMac"
chmod +x "$APP_BUNDLE/Contents/MacOS/NativelyMac"

cp "$MACOS_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> [4/5] Code signing application bundle with hardened entitlements..."
# Look for an available Apple Development identity in user keychain
SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)"

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "    Using valid code signing identity: $SIGNING_IDENTITY"
    codesign --force --deep --sign "$SIGNING_IDENTITY" \
        --entitlements "$MACOS_DIR/Resources/NativelyMac.entitlements" \
        "$APP_BUNDLE"
else
    echo "    No Apple Development certificate found; using ad-hoc signing with pinned bundle identifier requirement..."
    codesign --force --deep --sign - \
        -r='designated => identifier "com.natively.mac"' \
        --entitlements "$MACOS_DIR/Resources/NativelyMac.entitlements" \
        "$APP_BUNDLE"
fi

echo "==> [5/5] Verifying bundle code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

BUNDLE_SIZE="$(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "=============================================================================="
echo "🎉 SUCCESS: Native macOS application package built successfully!"
echo "📍 Location: $APP_BUNDLE"
echo "📦 Bundle Size: $BUNDLE_SIZE (vs ~550 MB legacy Electron app)"
echo "⚡️ Architecture: Apple Silicon Native (Swift 6, Metal, CoreML, AppKit, SwiftUI)"
echo "=============================================================================="
