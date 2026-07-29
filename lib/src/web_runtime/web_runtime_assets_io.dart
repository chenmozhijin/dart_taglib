// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const String taglibWebRuntimeDirectoryName = 'web_runtime';
const String taglibWebRuntimeManifestName = 'manifest.json';
const String taglibWebRuntimeDefaultOutput =
    'web/assets/packages/dart_taglib/web_runtime';

const List<String> taglibWebRuntimeArtifactNames = <String>[
  'taglib_bridge.js',
  'taglib_bridge.wasm',
  'taglib_bridge_web.js',
];

final class TaglibWebRuntimeManifest {
  const TaglibWebRuntimeManifest._(this.artifactHashes);

  final Map<String, String> artifactHashes;

  static Future<TaglibWebRuntimeManifest> load(
    Directory runtimeDirectory,
  ) async {
    final manifestFile = File.fromUri(
      runtimeDirectory.uri.resolve(taglibWebRuntimeManifestName),
    );
    if (!await manifestFile.exists()) {
      throw TaglibWebRuntimeException(
        'Web runtime manifest is missing: ${manifestFile.path}',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(await manifestFile.readAsString());
    } on Object catch (error) {
      throw TaglibWebRuntimeException(
        'Web runtime manifest is not valid JSON: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const TaglibWebRuntimeException(
        'Web runtime manifest root must be a JSON object.',
      );
    }
    if (decoded['schemaVersion'] != 1) {
      throw TaglibWebRuntimeException(
        'Unsupported web runtime manifest schema: '
        '${decoded['schemaVersion']}.',
      );
    }

    final artifacts = decoded['artifacts'];
    if (artifacts is! Map<String, Object?>) {
      throw const TaglibWebRuntimeException(
        'Web runtime manifest artifacts must be a JSON object.',
      );
    }
    if (artifacts.length != taglibWebRuntimeArtifactNames.length ||
        !taglibWebRuntimeArtifactNames.every(artifacts.containsKey)) {
      throw TaglibWebRuntimeException(
        'Web runtime manifest must contain exactly: '
        '${taglibWebRuntimeArtifactNames.join(', ')}.',
      );
    }

    final hashes = <String, String>{};
    for (final name in taglibWebRuntimeArtifactNames) {
      final value = artifacts[name];
      if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
        throw TaglibWebRuntimeException(
          'Web runtime manifest has an invalid SHA-256 for $name.',
        );
      }
      hashes[name] = value;
    }
    return TaglibWebRuntimeManifest._(Map<String, String>.unmodifiable(hashes));
  }
}

final class TaglibWebRuntimeIssue {
  const TaglibWebRuntimeIssue({required this.artifact, required this.message});

  final String artifact;
  final String message;

  @override
  String toString() => '$artifact: $message';
}

final class TaglibWebRuntimeInstallResult {
  const TaglibWebRuntimeInstallResult({
    required this.updated,
    required this.unchanged,
  });

  final List<String> updated;
  final List<String> unchanged;
}

final class TaglibWebRuntimeException implements Exception {
  const TaglibWebRuntimeException(this.message);

  final String message;

  @override
  String toString() => 'TaglibWebRuntimeException: $message';
}

Directory taglibWebRuntimeDirectory(Directory packageRoot) => Directory.fromUri(
  packageRoot.uri.resolve('$taglibWebRuntimeDirectoryName/'),
);

List<Uri> taglibWebRuntimeDependencyUris(Uri packageRoot) {
  final runtimeUri = packageRoot.resolve('$taglibWebRuntimeDirectoryName/');
  return <Uri>[
    runtimeUri.resolve(taglibWebRuntimeManifestName),
    for (final name in taglibWebRuntimeArtifactNames) runtimeUri.resolve(name),
  ];
}

Future<TaglibWebRuntimeManifest> validateTaglibWebRuntimeSource(
  Directory packageRoot,
) async {
  final runtimeDirectory = taglibWebRuntimeDirectory(packageRoot);
  final manifest = await TaglibWebRuntimeManifest.load(runtimeDirectory);
  final issues = await inspectTaglibWebRuntimeDirectory(
    runtimeDirectory,
    manifest,
  );
  if (issues.isNotEmpty) {
    throw TaglibWebRuntimeException(
      'Packaged web runtime failed validation:\n'
      '${issues.map((issue) => '  - $issue').join('\n')}',
    );
  }
  return manifest;
}

Future<List<TaglibWebRuntimeIssue>> inspectTaglibWebRuntimeDirectory(
  Directory directory,
  TaglibWebRuntimeManifest manifest,
) async {
  final issues = <TaglibWebRuntimeIssue>[];
  for (final name in taglibWebRuntimeArtifactNames) {
    final file = File.fromUri(directory.uri.resolve(name));
    if (!await file.exists()) {
      issues.add(
        TaglibWebRuntimeIssue(artifact: name, message: 'file is missing'),
      );
      continue;
    }
    final actualHash = await sha256File(file);
    final expectedHash = manifest.artifactHashes[name]!;
    if (actualHash != expectedHash) {
      issues.add(
        TaglibWebRuntimeIssue(
          artifact: name,
          message: 'SHA-256 mismatch (expected $expectedHash, got $actualHash)',
        ),
      );
    }
  }
  return List<TaglibWebRuntimeIssue>.unmodifiable(issues);
}

Future<TaglibWebRuntimeInstallResult> installTaglibWebRuntime({
  required Directory packageRoot,
  required Directory outputDirectory,
}) async {
  final sourceDirectory = taglibWebRuntimeDirectory(packageRoot);
  final manifest = await validateTaglibWebRuntimeSource(packageRoot);
  await outputDirectory.create(recursive: true);

  final updated = <String>[];
  final unchanged = <String>[];
  for (final name in taglibWebRuntimeArtifactNames) {
    final source = File.fromUri(sourceDirectory.uri.resolve(name));
    final destination = File.fromUri(outputDirectory.uri.resolve(name));
    final expectedHash = manifest.artifactHashes[name]!;

    if (await destination.exists() &&
        await sha256File(destination) == expectedHash) {
      unchanged.add(name);
      continue;
    }

    await _copyVerifiedFile(
      source: source,
      destination: destination,
      expectedHash: expectedHash,
    );
    updated.add(name);
  }

  final issues = await inspectTaglibWebRuntimeDirectory(
    outputDirectory,
    manifest,
  );
  if (issues.isNotEmpty) {
    throw TaglibWebRuntimeException(
      'Installed web runtime failed validation:\n'
      '${issues.map((issue) => '  - $issue').join('\n')}',
    );
  }

  return TaglibWebRuntimeInstallResult(
    updated: List<String>.unmodifiable(updated),
    unchanged: List<String>.unmodifiable(unchanged),
  );
}

Future<String> sha256File(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<void> _copyVerifiedFile({
  required File source,
  required File destination,
  required String expectedHash,
}) async {
  final nonce = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
  final temporary = File('${destination.path}.dart_taglib_$nonce.tmp');
  File? backup;

  try {
    await source.openRead().pipe(temporary.openWrite());
    final temporaryHash = await sha256File(temporary);
    if (temporaryHash != expectedHash) {
      throw TaglibWebRuntimeException(
        'Temporary copy of ${source.path} failed SHA-256 validation.',
      );
    }

    try {
      await temporary.rename(destination.path);
    } on FileSystemException {
      // Windows may reject replacement of an existing file. Keep the old file
      // so a failed update can be restored completely.
      if (await destination.exists()) {
        backup = File('${destination.path}.dart_taglib_$nonce.bak');
        await destination.rename(backup.path);
      }
      try {
        await temporary.rename(destination.path);
      } on Object {
        if (backup != null && await backup.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
    }

    if (backup != null && await backup.exists()) {
      await backup.delete();
    }
  } finally {
    if (await temporary.exists()) {
      await temporary.delete();
    }
  }
}
