#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="RecordInBarApp"
BUNDLE_ID="com.allertant.recordinbar"
VERSION="1.0"
BUILD_NUMBER="1"

CONFIGURATION="${1:-debug}"
DERIVED_DATA_PATH="${2:-${HOME}/Library/Developer/Xcode/DerivedData/${APP_NAME}-local}"

case "${CONFIGURATION}" in
  debug|release)
    ;;
  *)
    echo "Unsupported configuration: ${CONFIGURATION}" >&2
    echo "Usage: $0 [debug|release] [derived-data-path]" >&2
    exit 1
    ;;
esac

case "${CONFIGURATION}" in
  debug)
    CONFIGURATION_DIR="Debug"
    ;;
  release)
    CONFIGURATION_DIR="Release"
    ;;
esac

PRODUCTS_DIR="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION_DIR}"
SCRATCH_PATH="${DERIVED_DATA_PATH}/Build/SwiftPM"
TOOLCHAIN_HOME="${DERIVED_DATA_PATH}/Build/SwiftPMHome"
CLANG_MODULE_CACHE_PATH="${DERIVED_DATA_PATH}/Build/ModuleCache"
APP_BUNDLE_PATH="${PRODUCTS_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PLIST_PATH="${CONTENTS_DIR}/Info.plist"
EXECUTABLE_PATH="${SCRATCH_PATH}/${CONFIGURATION}/RecordInBarApp"

mkdir -p "${PRODUCTS_DIR}"
mkdir -p "${TOOLCHAIN_HOME}" "${CLANG_MODULE_CACHE_PATH}"

HOME="${TOOLCHAIN_HOME}" \
CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH}" \
swift build \
  --package-path "${REPO_DIR}" \
  --product "${APP_NAME}" \
  --configuration "${CONFIGURATION}" \
  --scratch-path "${SCRATCH_PATH}" \
  --disable-sandbox

rm -rf "${APP_BUNDLE_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"

cat > "${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_BUNDLE_PATH}" >/dev/null

echo "Built app bundle:"
echo "${APP_BUNDLE_PATH}"
