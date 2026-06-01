#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FloatingTodo"
BUNDLE_ID="com.cmi.floatingtodo"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
TARGET_BUNDLE="/Applications/$APP_NAME.app"
TRASH_DIR="$HOME/.Trash"
BACKUP_BUNDLE="$TRASH_DIR/$APP_NAME.replaced-$(date -u +%Y-%m-%dT%H-%M-%SZ).app"
EXECUTABLE="$ROOT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"
RESOURCE_BUNDLE="$ROOT_DIR/.build/arm64-apple-macosx/release/${APP_NAME}_${APP_NAME}.bundle"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# SwiftPM 生成的 Bundle.module 会先查找 app bundle 根目录下的资源 bundle。
cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/${APP_NAME}_${APP_NAME}.bundle"

if [[ -d "$TARGET_BUNDLE" ]]; then
  CURRENT_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET_BUNDLE/Contents/Info.plist")"
  if [[ "$CURRENT_ID" != "$BUNDLE_ID" ]]; then
    echo "Refusing to replace $TARGET_BUNDLE: bundle id is $CURRENT_ID" >&2
    exit 1
  fi
fi

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 0.8

mkdir -p "$TRASH_DIR"
if [[ -d "$TARGET_BUNDLE" ]]; then
  mv "$TARGET_BUNDLE" "$BACKUP_BUNDLE"
fi

cp -R "$APP_BUNDLE" "$TARGET_BUNDLE"
open -n "$TARGET_BUNDLE"

echo "Installed: $TARGET_BUNDLE"
echo "Backup: $BACKUP_BUNDLE"
