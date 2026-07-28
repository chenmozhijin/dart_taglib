// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_taglib/src/web_runtime/install_web_runtime_command.dart';
import 'package:dart_taglib/src/web_runtime/web_runtime_assets_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temporaryRoot;
  late Directory packageRoot;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'dart_taglib_web_runtime_test_',
    );
    packageRoot = Directory(p.join(temporaryRoot.path, 'package'));
    await _writeRuntime(packageRoot);
  });

  tearDown(() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('validates the fixed packaged runtime and dependency list', () async {
    final manifest = await validateTaglibWebRuntimeSource(packageRoot);

    expect(
      manifest.artifactHashes.keys,
      orderedEquals(taglibWebRuntimeArtifactNames),
    );
    expect(
      taglibWebRuntimeDependencyUris(packageRoot.uri),
      orderedEquals(<Uri>[
        packageRoot.uri.resolve('web_runtime/manifest.json'),
        for (final name in taglibWebRuntimeArtifactNames)
          packageRoot.uri.resolve('web_runtime/$name'),
      ]),
    );
  });

  test('rejects manifest artifacts outside the fixed allowlist', () async {
    final manifestFile = File(
      p.join(packageRoot.path, 'web_runtime', 'manifest.json'),
    );
    final decoded = jsonDecode(await manifestFile.readAsString()) as Map;
    final artifacts = decoded['artifacts'] as Map;
    artifacts['../outside.js'] = List<String>.filled(64, '0').join();
    await manifestFile.writeAsString(jsonEncode(decoded));

    await expectLater(
      validateTaglibWebRuntimeSource(packageRoot),
      throwsA(
        isA<TaglibWebRuntimeException>().having(
          (error) => error.message,
          'message',
          contains('must contain exactly'),
        ),
      ),
    );
  });

  test(
    'rejects a packaged runtime file that no longer matches manifest',
    () async {
      final source = File(
        p.join(packageRoot.path, 'web_runtime', 'taglib_bridge.wasm'),
      );
      await source.writeAsString('tampered source');

      await expectLater(
        validateTaglibWebRuntimeSource(packageRoot),
        throwsA(
          isA<TaglibWebRuntimeException>().having(
            (error) => error.message,
            'message',
            contains('SHA-256 mismatch'),
          ),
        ),
      );
    },
  );

  test('reports missing and modified destination artifacts', () async {
    final manifest = await validateTaglibWebRuntimeSource(packageRoot);
    final output = Directory(p.join(temporaryRoot.path, 'output'));
    await output.create();
    await File(p.join(output.path, 'taglib_bridge.js')).writeAsString('bad');

    final issues = await inspectTaglibWebRuntimeDirectory(output, manifest);

    expect(issues, hasLength(3));
    expect(
      issues.map((issue) => issue.artifact),
      containsAll(taglibWebRuntimeArtifactNames),
    );
    expect(
      issues
          .singleWhere((issue) => issue.artifact == 'taglib_bridge.js')
          .message,
      contains('SHA-256 mismatch'),
    );
  });

  test(
    'installs, updates, and preserves unrelated destination files',
    () async {
      final output = Directory(p.join(temporaryRoot.path, 'output'));
      await output.create();
      final unrelated = File(p.join(output.path, 'keep.txt'));
      await unrelated.writeAsString('keep');
      await File(p.join(output.path, 'taglib_bridge.js')).writeAsString('old');

      final first = await installTaglibWebRuntime(
        packageRoot: packageRoot,
        outputDirectory: output,
      );
      final second = await installTaglibWebRuntime(
        packageRoot: packageRoot,
        outputDirectory: output,
      );

      expect(first.updated, orderedEquals(taglibWebRuntimeArtifactNames));
      expect(first.unchanged, isEmpty);
      expect(second.updated, isEmpty);
      expect(second.unchanged, orderedEquals(taglibWebRuntimeArtifactNames));
      expect(await unrelated.readAsString(), 'keep');
      expect(
        output
            .listSync()
            .whereType<File>()
            .map((file) => p.basename(file.path))
            .where((name) => name.contains('.dart_taglib_')),
        isEmpty,
      );
    },
  );

  test(
    'command installs and check detects tampering without modifying it',
    () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final output = Directory(
        p.join(temporaryRoot.path, taglibWebRuntimeDefaultOutput),
      );

      final installCode = await runInstallWebRuntimeCommand(
        const <String>[],
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        currentDirectory: temporaryRoot,
        packageRoot: packageRoot,
      );
      final cleanCheckCode = await runInstallWebRuntimeCommand(
        const <String>['--check'],
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        currentDirectory: temporaryRoot,
        packageRoot: packageRoot,
      );
      final tampered = File(p.join(output.path, 'taglib_bridge.wasm'));
      await tampered.writeAsString('tampered');
      final tamperedBytes = await tampered.readAsBytes();
      final failedCheckCode = await runInstallWebRuntimeCommand(
        const <String>['--check'],
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        currentDirectory: temporaryRoot,
        packageRoot: packageRoot,
      );

      expect(installCode, 0);
      expect(cleanCheckCode, 0);
      expect(failedCheckCode, 1);
      expect(await tampered.readAsBytes(), orderedEquals(tamperedBytes));
      expect(stderrBuffer.toString(), contains('SHA-256 mismatch'));
    },
  );
}

Future<void> _writeRuntime(Directory packageRoot) async {
  final runtime = Directory(p.join(packageRoot.path, 'web_runtime'));
  await runtime.create(recursive: true);
  final hashes = <String, String>{};
  for (final name in taglibWebRuntimeArtifactNames) {
    final bytes = utf8.encode('fixture:$name');
    await File(p.join(runtime.path, name)).writeAsBytes(bytes);
    hashes[name] = sha256.convert(bytes).toString();
  }
  await File(p.join(runtime.path, 'manifest.json')).writeAsString(
    jsonEncode(<String, Object>{'schemaVersion': 1, 'artifacts': hashes}),
  );
}
