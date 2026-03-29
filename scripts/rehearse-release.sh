#!/usr/bin/env bash
set -euo pipefail

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
PROJECT_PATH="AudioConverter.xcodeproj"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Release/AudioConverter.app"

echo "+ DEVELOPER_DIR=$DEVELOPER_DIR xcodebuild -project $PROJECT_PATH -scheme AudioConverter -configuration Release SYMROOT=$BUILD_DIR build"
DEVELOPER_DIR="$DEVELOPER_DIR" \
  xcodebuild -project "$PROJECT_PATH" -scheme AudioConverter -configuration Release SYMROOT="$BUILD_DIR" build

echo "+ scripts/release-sign-and-notarize.sh --mode rehearse --app $APP_PATH"
scripts/release-sign-and-notarize.sh --mode rehearse --app "$APP_PATH"
