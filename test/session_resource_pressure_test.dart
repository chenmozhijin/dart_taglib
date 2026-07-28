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

      // 独立进程隔离其他测试的 JIT 与堆增长，使 RSS 只反映本压力场景。
      // 直接执行脚本并加载父测试已构建的动态库，避免 dart run 再次触发
      // build hook；Windows 不允许替换父进程仍在使用的 DLL。
      final result = await Process.run(
        Platform.resolvedExecutable,
        const <String>[
          '--disable-dart-dev',
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
