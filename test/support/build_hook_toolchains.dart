// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:code_assets/code_assets.dart';

final class AndroidHookToolchain {
  AndroidHookToolchain({
    required this.ndkRoot,
    required this.cCompiler,
    this.readElf,
  });

  final Uri ndkRoot;
  final CCompilerConfig cCompiler;
  final Uri? readElf;
}

final class AppleHookToolchain {
  AppleHookToolchain({required this.cCompiler});

  final CCompilerConfig cCompiler;
}

bool hasCmake() => _commandSucceeds('cmake', const <String>['--version']);

AndroidHookToolchain? tryFindAndroidHookToolchain() {
  final ndkRoot = _locateAndroidNdkRoot();
  if (ndkRoot == null) {
    return null;
  }

  final extension = Platform.isWindows ? '.exe' : '';
  final binDirectory = _locateAndroidNdkBinDirectory(ndkRoot);
  if (binDirectory == null) {
    return null;
  }

  final compiler = File.fromUri(binDirectory.uri.resolve('clang$extension'));
  final linker = File.fromUri(binDirectory.uri.resolve('ld.lld$extension'));
  final archiver = File.fromUri(binDirectory.uri.resolve('llvm-ar$extension'));
  if (!compiler.existsSync() ||
      !linker.existsSync() ||
      !archiver.existsSync()) {
    return null;
  }

  Uri? readElf;
  final llvmReadElf = File.fromUri(
    binDirectory.uri.resolve('llvm-readelf$extension'),
  );
  if (llvmReadElf.existsSync()) {
    readElf = llvmReadElf.uri;
  }

  return AndroidHookToolchain(
    ndkRoot: ndkRoot,
    cCompiler: CCompilerConfig(
      compiler: compiler.uri,
      linker: linker.uri,
      archiver: archiver.uri,
    ),
    readElf: readElf,
  );
}

AppleHookToolchain? tryFindAppleHookToolchain() {
  if (!Platform.isMacOS) {
    return null;
  }

  final clang = _findExecutableWithXcrun('clang');
  final ld = _findExecutableWithXcrun('ld');
  final ar = _findExecutableWithXcrun('ar');
  if (clang == null || ld == null || ar == null) {
    return null;
  }

  return AppleHookToolchain(
    cCompiler: CCompilerConfig(compiler: clang, linker: ld, archiver: ar),
  );
}

Object skipUnlessCmake() {
  return hasCmake() ? false : 'cmake is not available';
}

Object skipUnlessAndroidHookToolchain() {
  if (!hasCmake()) {
    return 'cmake is not available';
  }
  return tryFindAndroidHookToolchain() == null
      ? 'Android NDK toolchain not found'
      : false;
}

Object skipUnlessAppleHookToolchain() {
  if (!hasCmake()) {
    return 'cmake is not available';
  }
  return tryFindAppleHookToolchain() == null
      ? 'Apple toolchain not found'
      : false;
}

Uri? _locateAndroidNdkRoot() {
  final env = Platform.environment;
  final candidates = <String?>[
    env['ANDROID_NDK'],
    env['ANDROID_NDK_HOME'],
    env['ANDROID_NDK_LATEST_HOME'],
    env['ANDROID_NDK_ROOT'],
  ].whereType<String>();

  for (final candidate in candidates) {
    final directory = Directory(candidate);
    if (_isAndroidNdkRoot(directory)) {
      return directory.uri;
    }
  }

  final androidHome = env['ANDROID_HOME'];
  if (androidHome != null) {
    final ndkDirectory = Directory.fromUri(
      Directory(androidHome).uri.resolve('ndk/'),
    );
    if (ndkDirectory.existsSync()) {
      final versions = ndkDirectory.listSync().whereType<Directory>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final versionDirectory in versions) {
        if (_isAndroidNdkRoot(versionDirectory)) {
          return versionDirectory.uri;
        }
      }
    }
  }

  return null;
}

Directory? _locateAndroidNdkBinDirectory(Uri ndkRoot) {
  final prebuiltDirectory = Directory.fromUri(
    ndkRoot.resolve('toolchains/llvm/prebuilt/'),
  );
  if (!prebuiltDirectory.existsSync()) {
    return null;
  }

  final candidates = prebuiltDirectory
      .listSync()
      .whereType<Directory>()
      .map((directory) => Directory.fromUri(directory.uri.resolve('bin/')))
      .toList();
  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }
  return null;
}

bool _isAndroidNdkRoot(Directory directory) {
  return Directory.fromUri(
    directory.uri.resolve('toolchains/llvm/prebuilt/'),
  ).existsSync();
}

Uri? _findExecutableWithXcrun(String executable) {
  final result = Process.runSync('xcrun', <String>['--find', executable]);
  if (result.exitCode != 0) {
    return null;
  }

  final output = (result.stdout as Object?)?.toString().trim() ?? '';
  if (output.isEmpty) {
    return null;
  }
  return File(output).uri;
}

bool _commandSucceeds(String executable, List<String> arguments) {
  try {
    final result = Process.runSync(executable, arguments);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
