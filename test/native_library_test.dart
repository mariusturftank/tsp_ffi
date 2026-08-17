// Packaging guards for the prebuilt Android library.
//
// These inspect the shipped .so rather than calling into it, so they run on any
// host. They exist because two packaging regressions shipped unnoticed:
//
//  * The committed .so was unstripped — 293 MB, of which ~290 MB was DWARF.
//  * A stale patch to or-tools stopped applying, so abseil and protobuf built
//    as shared libraries and ~18k of their symbols leaked into the dynamic
//    symbol table, pinning OR-Tools code that --gc-sections should have dropped.
//
// Both are invisible in Dart-level tests and only show up in the binary.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The prebuilt library that ships to consumers of this plugin.
final _androidLib = File('android/src/main/jniLibs/arm64-v8a/libtsp_ffi.so');

/// The C API this package intends to expose.
final _header = File('src/tsp_ffi.h');

/// Exported entry points are those declared in tsp_ffi.h. Everything else —
/// OR-Tools, abseil, protobuf, libc++ — must stay internal.
Set<String> _declaredEntryPoints() {
  final source = _header.readAsStringSync();
  final names = RegExp(r'\b([a-z_][a-z_0-9]*)\s*\(').allMatches(source).map((m) => m.group(1)!);
  return names
      .where((n) => n.startsWith('tsp_') || n.startsWith('routing_') || n.startsWith('assignment_'))
      .toSet();
}

/// Resolves an ELF reader, preferring binutils and falling back to LLVM's.
String? _readelf() {
  for (final candidate in ['readelf', 'llvm-readelf']) {
    final which = Process.runSync('which', [candidate]);
    if (which.exitCode == 0) return candidate;
  }
  return null;
}

/// Symbols the library defines and exports — excludes imports (`UND`) and
/// anything hidden by the visibility preset.
Set<String> _exportedFunctions(String readelf, File lib) {
  final out = Process.runSync(readelf, ['--dyn-syms', '-W', lib.path]).stdout as String;
  final exported = <String>{};
  for (final line in out.split('\n')) {
    final f = line.trim().split(RegExp(r'\s+'));
    if (f.length < 8) continue;
    if (f[3] != 'FUNC' || f[5] != 'DEFAULT' || f[6] == 'UND') continue;
    exported.add(f[7].split('@').first);
  }
  return exported;
}

void main() {
  final readelf = _readelf();

  group('prebuilt Android library', () {
    setUp(() {
      if (!_androidLib.existsSync()) {
        fail('${_androidLib.path} is missing — build it with '
            'cd src && ./build_android.sh arm64-v8a');
      }
    });

    test('exports exactly the entry points declared in tsp_ffi.h', () {
      expect(_exportedFunctions(readelf!, _androidLib), _declaredEntryPoints());
    }, skip: readelf == null ? 'no readelf available' : null);

    test('is stripped of debug info', () {
      final out = Process.runSync(readelf!, ['-S', '-W', _androidLib.path]).stdout as String;
      expect(
        out,
        isNot(contains('.debug_info')),
        reason: 'DWARF in the shipped .so cost ~290 MB before it was stripped; '
            'see the strip step in src/build_android.sh',
      );
    }, skip: readelf == null ? 'no readelf available' : null);

    test('ships arm64-v8a and nothing else', () {
      // Deliberate: every extra ABI is another full OR-Tools build and another
      // ~11 MB artifact. android/build.gradle declares the matching abiFilters,
      // and this asserts the two stay in agreement.
      final abis = Directory('android/src/main/jniLibs')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
          .toSet();
      expect(abis, {'arm64-v8a'});
    });

    test('stays within a sane size budget', () {
      // Measured at ~11 MB. The ceiling is deliberately loose — it is here to
      // catch a return to hundreds of megabytes, not to track normal growth.
      const budget = 40 * 1024 * 1024;
      expect(_androidLib.lengthSync(), lessThan(budget));
    });
  });

  group('tsp_ffi.h', () {
    test('declares the entry points the Dart bindings rely on', () {
      expect(
        _declaredEntryPoints(),
        containsAll([
          'tsp_solve_with_distance_matrix',
          'tsp_solution_get_route',
          'tsp_solution_free',
          'assignment_objective_value',
        ]),
      );
    });
  });
}
