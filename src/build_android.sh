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

# Apply the static-linking patch to or-tools. This is load-bearing: or-tools'
# cmake/dependencies/CMakeLists.txt does a plain `set(BUILD_SHARED_LIBS ON)`,
# which shadows the cache variable we FORCE in CMakeLists.txt and builds abseil
# and protobuf as shared libraries. Combined with the hidden-visibility preset,
# that fails the link with undefined absl::flags_internal symbols.
#
# A "patch didn't apply" here must be fatal, not a warning — the build gets
# much further before failing in a way that looks unrelated.
ORTOOLS_DIR="$SCRIPT_DIR/third_party/or-tools"
PATCH_FILE="$SCRIPT_DIR/patches/or-tools-static-deps.patch"
if [ -f "$PATCH_FILE" ] && [ -d "$ORTOOLS_DIR" ]; then
  echo "Applying static-linking patch to or-tools..."
  if git -C "$ORTOOLS_DIR" apply --reverse --check "$PATCH_FILE" 2>/dev/null; then
    echo "  already applied"
  elif git -C "$ORTOOLS_DIR" apply "$PATCH_FILE"; then
    echo "  applied"
  else
    echo "" >&2
    echo "ERROR: $PATCH_FILE does not apply to the vendored or-tools tree." >&2
    echo "       Its context drifts whenever or-tools is bumped. Without it," >&2
    echo "       abseil/protobuf build SHARED and the link fails later with" >&2
    echo "       'undefined symbol: absl::...::flags_internal::...'." >&2
    echo "" >&2
    echo "       To regenerate: set BUILD_SHARED_LIBS and protobuf_BUILD_SHARED_LIBS" >&2
    echo "       to OFF in or-tools' cmake/dependencies/CMakeLists.txt, then:" >&2
    echo "         git -C $ORTOOLS_DIR diff -U6 cmake/dependencies/CMakeLists.txt \\" >&2
    echo "           > $PATCH_FILE" >&2
    exit 1
  fi
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

  # Keep this modest: the thin-LTO link at the end of the build holds the whole
  # program in memory, so a high -j can push the machine into swap or OOM.
  "$CMAKE_BIN" --build "$BUILD_DIR" --target tsp_ffi --config "$BUILD_TYPE" \
    -j"${BUILD_JOBS:-8}"

  # Strip DWARF debug info before shipping to jniLibs. The AGP strips native
  # libs on the way into the APK regardless, but keeping a fat unstripped
  # .so in the repo bloats git and CI artifacts (~294 MB unstripped vs
  # ~16 MB stripped for arm64-v8a).
  NDK_STRIP="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
  if [ -x "$NDK_STRIP" ]; then
    "$NDK_STRIP" --strip-all "$BUILD_DIR/libtsp_ffi.so"
  else
    echo "WARN: llvm-strip not found at $NDK_STRIP — shipping unstripped .so"
  fi

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
