# tsp_ffi

A new Flutter FFI plugin project.

## Platform support

**Android, `arm64-v8a` only.** The native library statically links OR-Tools,
so every additional ABI is a full OR-Tools build (about an hour) and another
~11 MB binary. `armeabi-v7a` and `x86_64` are deliberately not shipped, which
means **x86_64 emulators cannot run this plugin** — use an arm64 device or an
arm64 system image.

Apps consuming this plugin should declare the same filter, so an unsupported
ABI fails at build time rather than at `DynamicLibrary.open`:

```kotlin
// android/app/build.gradle.kts
defaultConfig {
    ndk {
        abiFilters += listOf("arm64-v8a")
    }
}
```

## Building the native library

The `.so` is prebuilt and committed under `android/src/main/jniLibs/`, because
building OR-Tools from source on every consumer build is not practical.
Regenerate it after changing anything under `src/`:

```bash
cd src && ./build_android.sh arm64-v8a      # BUILD_JOBS=8 by default
```

The build applies `src/patches/or-tools-static-deps.patch`, which forces the
vendored OR-Tools to build abseil and protobuf statically. That patch's context
drifts whenever OR-Tools is bumped; the script fails loudly with regeneration
instructions if it no longer applies.

## Running tests

The functional tests call the real native library, so the loader needs to find
the Linux host build:

```bash
LD_LIBRARY_PATH=src/build:src/build/lib fvm flutter test
```

## Getting Started

This project is a starting point for a Flutter
[FFI plugin](https://flutter.dev/to/ffi-package),
a specialized package that includes native code directly invoked with Dart FFI.

## Project structure

This template uses the following structure:

* `src`: Contains the native source code, and a CmakeFile.txt file for building
  that source code into a dynamic library.

* `src/third_party/or-tools`: Contains a pinned vendored copy of OR-Tools used by
  the native build. This directory should contain source files only, not a
  nested `.git` directory.

* `lib`: Contains the Dart code that defines the API of the plugin, and which
  calls into the native code using `dart:ffi`.

* platform folders (`android`, `ios`, `windows`, etc.): Contains the build files
  for building and bundling the native code library with the platform application.

## Building and bundling native code

The `pubspec.yaml` specifies FFI plugins as follows:

```yaml
  plugin:
    platforms:
      some_platform:
        ffiPlugin: true
```

This configuration invokes the native build for the various target platforms
and bundles the binaries in Flutter applications using these FFI plugins.

This can be combined with dartPluginClass, such as when FFI is used for the
implementation of one platform in a federated plugin:

```yaml
  plugin:
    implements: some_other_plugin
    platforms:
      some_platform:
        dartPluginClass: SomeClass
        ffiPlugin: true
```

A plugin can have both FFI and method channels:

```yaml
  plugin:
    platforms:
      some_platform:
        pluginClass: SomeName
        ffiPlugin: true
```

The native build systems that are invoked by FFI (and method channel) plugins are:

* For Android: Gradle, which invokes the Android NDK for native builds.
  * See the documentation in android/build.gradle.
* For iOS and MacOS: Xcode, via CocoaPods.
  * See the documentation in ios/tsp_ffi.podspec.
  * See the documentation in macos/tsp_ffi.podspec.
* For Linux and Windows: CMake.
  * See the documentation in linux/CMakeLists.txt.
  * See the documentation in windows/CMakeLists.txt.

## Binding to native code

To use the native code, bindings in Dart are needed.
To avoid writing these by hand, they are generated from the header file
(`src/tsp_ffi.h`) by `package:ffigen`.
Regenerate the bindings by running `dart run ffigen --config ffigen.yaml`.

## Vendored dependencies

OR-Tools is kept as a vendored source snapshot under `src/third_party/or-tools`
instead of as a nested Git repository. This keeps the parent repository clean
while still allowing CMake to build OR-Tools with `add_subdirectory(...)`.

## Invoking native code

Very short-running native functions can be directly invoked from any isolate.
For example, see `sum` in `lib/tsp_ffi.dart`.

Longer-running functions should be invoked on a helper isolate to avoid
dropping frames in Flutter applications.
For example, see `sumAsync` in `lib/tsp_ffi.dart`.

## Flutter help

For help getting started with Flutter, view our
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

The plugin project was generated without specifying the `--platforms` flag, so no platforms are currently supported.
To add platforms, run `flutter create -t plugin_ffi --platforms <platforms> .` in this directory.
You can also find a detailed instruction on how to add platforms in the `pubspec.yaml` at https://flutter.dev/to/pubspec-plugin-platforms.
# tsp_ffi
