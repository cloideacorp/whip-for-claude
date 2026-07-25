#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Kirbac.app"
SRC="$ROOT/Sources/Kirbac"
RES="$ROOT/Resources"
SDK="$(xcrun --show-sdk-path)"
BUILD="$ROOT/build"
SOURCES=(
  "$SRC"/main.swift
  "$SRC"/AppDelegate.swift
  "$SRC"/L10n.swift
  "$SRC"/MacroSender.swift
  "$SRC"/WhipPhysics.swift
  "$SRC"/WhipView.swift
  "$SRC"/WhipWindowController.swift
)
FRAMEWORKS=(
  -framework AppKit
  -framework Carbon
  -framework AVFoundation
  -framework ApplicationServices
  -framework QuartzCore
)

rm -rf "$APP" "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD"

compile() {
  local arch="$1"
  local out="$2"
  swiftc -O \
    -target "${arch}-apple-macosx13.0" \
    -sdk "$SDK" \
    "${FRAMEWORKS[@]}" \
    -o "$out" \
    "${SOURCES[@]}"
}

compile arm64 "$BUILD/Kirbac-arm64"
compile x86_64 "$BUILD/Kirbac-x86_64"
lipo -create -output "$APP/Contents/MacOS/Kirbac" \
  "$BUILD/Kirbac-arm64" "$BUILD/Kirbac-x86_64"

cp "$RES/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp -R "$RES/sounds" "$APP/Contents/Resources/"
cp -R "$RES/icon" "$APP/Contents/Resources/"

codesign --force --deep --sign - "$APP"
file "$APP/Contents/MacOS/Kirbac"
echo "Built $APP (universal)"
