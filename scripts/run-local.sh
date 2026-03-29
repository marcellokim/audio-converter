#!/usr/bin/env bash
set -euo pipefail

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
PROJECT_PATH="AudioConverter.xcodeproj"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Debug/AudioConverter.app"

if [ -x /opt/homebrew/bin/xcodegen ]; then
  XCODEGEN_BIN="/opt/homebrew/bin/xcodegen"
elif command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN_BIN="$(command -v xcodegen)"
else
  echo "error: xcodegen is required on PATH or at /opt/homebrew/bin/xcodegen" >&2
  exit 1
fi

echo "+ DEVELOPER_DIR=$DEVELOPER_DIR $XCODEGEN_BIN generate"
DEVELOPER_DIR="$DEVELOPER_DIR" "$XCODEGEN_BIN" generate

echo "+ DEVELOPER_DIR=$DEVELOPER_DIR xcodebuild -project $PROJECT_PATH -scheme AudioConverter -configuration Debug SYMROOT=$BUILD_DIR build"
DEVELOPER_DIR="$DEVELOPER_DIR" \
  xcodebuild -project "$PROJECT_PATH" -scheme AudioConverter -configuration Debug SYMROOT="$BUILD_DIR" build

echo "+ open $APP_PATH"
open "$APP_PATH"
