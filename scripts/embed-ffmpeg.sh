#!/bin/sh
set -eu

SOURCE_FFMPEG="${PROJECT_DIR}/AudioConverter/Resources/ffmpeg/ffmpeg"
DEST_DIR="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Helpers"
DEST_FFMPEG="${DEST_DIR}/ffmpeg"
LEGACY_DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ffmpeg"
STAMP_DIR="${DERIVED_FILE_DIR}"
STAMP_FILE="${STAMP_DIR}/embed-ffmpeg.stamp"

rm -rf "${LEGACY_DEST_DIR}"
rm -f "${DEST_DIR}/.embed-ffmpeg.stamp"
mkdir -p "${DEST_DIR}"
mkdir -p "${STAMP_DIR}"

if [ ! -f "${SOURCE_FFMPEG}" ]; then
  echo "warning: vendored ffmpeg binary not found at ${SOURCE_FFMPEG}; skipping embed step"
  : > "${STAMP_FILE}"
  exit 0
fi

cp "${SOURCE_FFMPEG}" "${DEST_FFMPEG}"
chmod +x "${DEST_FFMPEG}"
: > "${STAMP_FILE}"
