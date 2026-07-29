// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'explicit close keeps native session RSS bounded under pressure',
    () async {
      final libraryName = switch (Platform.operatingSystem) {
        'windows' => 'taglib_bridge.dll',
        'linux' => 'libtaglib_bridge.so',
        'macos' => 'libtaglib_bridge.dylib',
        final operatingSystem => throw UnsupportedError(
          'Unsupported RSS probe platform: $operatingSystem',
        ),
      };
      final library = File('.dart_tool/lib/$libraryName').absolute;
      expect(
        library.existsSync(),
        isTrue,
        reason: 'Native Assets did not bundle ${library.path}.',
      );

      // Isolate JIT and heap growth from other tests so RSS reflects only this
      // pressure scenario. Execute the probe directly with the library built
      // by the parent test to avoid rerunning the build hook; Windows cannot
      // replace a DLL that the parent process still uses.
      final result = await Process.run(
        Platform.resolvedExecutable,
        const <String>[
          '--disable-dart-dev',
          '--enable-vm-service=0',
          '--disable-service-auth-codes',
          '--packages=.dart_tool/package_config.json',
          'test/support/session_rss_probe.dart',
        ],
        workingDirectory: Directory.current.path,
        environment: <String, String>{
          ...Platform.environment,
          'TAGLIB_BRIDGE_LIB': library.path,
        },
      );
      final stdoutText = result.stdout as String;
      final evidenceLines = const LineSplitter()
          .convert(stdoutText)
          .where((line) => line.startsWith('DART_TAGLIB_RSS '))
          .toList();

      expect(
        evidenceLines,
        hasLength(1),
        reason:
            'RSS probe did not emit one evidence row.\nstdout:\n$stdoutText\n'
            'stderr:\n${result.stderr}',
      );
      final evidence =
          jsonDecode(evidenceLines.single.substring('DART_TAGLIB_RSS '.length))
              as Map<String, Object?>;

      expect(
        result.exitCode,
        0,
        reason:
            'Native session RSS exceeded the bounded-growth limit: '
            '$evidence\nstderr:\n${result.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
