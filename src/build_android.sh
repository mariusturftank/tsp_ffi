#!/usr/bin/env bash
# Build libtsp_ffi.so for Android ABIs using the NDK.
# Usage: ./build_android.sh [abi...]
#   e.g. ./build_android.sh arm64-v8a
#        ./build_android.sh              (defaults to arm64-v8a)
#
# Prerequisites:
#   - ANDROID_SDK_ROOT or ANDROID_HOME set (or edit ANDROID_SDK below)
#   - NDK installed via sdkmanager
#
# Output goes to ../android/src/main/jniLibs/<abi>/libtsp_ffi.so

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Configuration ---
ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
# Pick the newest NDK available
NDK_VERSION="$(ls -1 "$ANDROID_SDK/ndk" | sort -V | tail -1)"
NDK_ROOT="$ANDROID_SDK/ndk/$NDK_VERSION"
CMAKE_BIN="$(command -v cmake)"  # Use system cmake (3.20+)
API_LEVEL=24
BUILD_TYPE=Release

ABIS=("${@:-arm64-v8a}")
if [ $# -eq 0 ]; then
  ABIS=(arm64-v8a)
fi

TOOLCHAIN="$NDK_ROOT/build/cmake/android.toolchain.cmake"
if [ ! -f "$TOOLCHAIN" ]; then
  echo "ERROR: NDK toolchain not found at $TOOLCHAIN"
  echo "       NDK_ROOT=$NDK_ROOT"
  exit 1
fi

OUTPUT_BASE="$SCRIPT_DIR/../android/src/main/jniLibs"

# Apply static-linking patch to or-tools (idempotent via --forward)
ORTOOLS_DIR="$SCRIPT_DIR/third_party/or-tools"
PATCH_FILE="$SCRIPT_DIR/patches/or-tools-static-deps.patch"
if [ -f "$PATCH_FILE" ] && [ -d "$ORTOOLS_DIR" ]; then
  echo "Applying static-linking patch to or-tools..."
  git -C "$ORTOOLS_DIR" apply --check "$PATCH_FILE" 2>/dev/null \
    && git -C "$ORTOOLS_DIR" apply "$PATCH_FILE" \
    || echo "  (patch already applied or not needed)"
fi

for ABI in "${ABIS[@]}"; do
  echo "========================================"
  echo "Building for $ABI ..."
  echo "========================================"

  BUILD_DIR="$SCRIPT_DIR/build-android-$ABI"
  mkdir -p "$BUILD_DIR"

  "$CMAKE_BIN" -S "$SCRIPT_DIR" -B "$BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="android-$API_LEVEL" \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

  "$CMAKE_BIN" --build "$BUILD_DIR" --target tsp_ffi --config "$BUILD_TYPE" \
    -j16

  # Install to jniLibs
  DEST="$OUTPUT_BASE/$ABI"
  mkdir -p "$DEST"
  cp "$BUILD_DIR/libtsp_ffi.so" "$DEST/libtsp_ffi.so"

  echo ">>> Installed: $DEST/libtsp_ffi.so"
done

echo ""
echo "Done. Pre-built libraries are in:"
echo "  $OUTPUT_BASE/"
ls -lR "$OUTPUT_BASE/"
