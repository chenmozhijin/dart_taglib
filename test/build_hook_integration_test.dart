// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:dart_taglib/src/web_runtime/web_runtime_assets_io.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as taglib_build_hook;
import 'support/build_hook_toolchains.dart';

const buildHookTimeout = Timeout(Duration(minutes: 10));

void main() {
  final androidToolchain = tryFindAndroidHookToolchain();
  final appleToolchain = tryFindAppleHookToolchain();

  test(
    'desktop build hook emits bundled library for the host target',
    () async {
      await testCodeBuildHook(
        mainMethod: taglib_build_hook.main,
        targetOS: _hostTargetOS(),
        targetArchitecture: Architecture.current,
        check: (input, output) {
          final assets = output.assets.code;
          expect(assets, hasLength(1));
          final asset = assets.single;
          expect(asset.linkMode, DynamicLoadingBundled());
          expect(asset.file, isNotNull);
          expect(File.fromUri(asset.file!).existsSync(), isTrue);
          expect(
            asset.file!.toFilePath(),
            contains('${_hostTargetOS().name}-${Architecture.current.name}'),
          );
          expect(
            asset.id,
            'package:${input.packageName}/src/ffi_native/taglib_bridge_ffi.dart',
          );
          expect(
            output.dependencies,
            containsAll(<Uri>[
              ...taglibWebRuntimeDependencyUris(input.packageRoot),
              input.packageRoot.resolve('native/taglib_bridge/'),
              input.packageRoot.resolve('third_party/taglib/'),
            ]),
          );
        },
      );
    },
    skip: skipUnlessCmake(),
    timeout: buildHookTimeout,
  );

  test(
    'android build hook emits a bundled .so without libc++_shared dependency',
    () async {
      final toolchain = androidToolchain!;
      await testCodeBuildHook(
        mainMethod: taglib_build_hook.main,
        targetOS: OS.android,
        targetArchitecture: Architecture.arm64,
        targetAndroidNdkApi: 30,
        cCompiler: toolchain.cCompiler,
        check: (input, output) {
          final asset = output.assets.code.single;
          final libraryFile = File.fromUri(asset.file!);
          expect(libraryFile.existsSync(), isTrue);
          expect(libraryFile.uri.path, contains('android-arm64'));
          expect(asset.file!.pathSegments.last, 'libtaglib_bridge.so');
          _expectNoSharedLibCppDependency(toolchain.readElf, libraryFile);
          expect(input.config.code.android.targetNdkApi, 30);
        },
      );
    },
    skip: skipUnlessAndroidHookToolchain(),
    timeout: buildHookTimeout,
  );

  test(
    'ios build hook emits a bundled dylib for iphoneos arm64',
    () async {
      final toolchain = appleToolchain!;
      await testCodeBuildHook(
        mainMethod: taglib_build_hook.main,
        targetOS: OS.iOS,
        targetArchitecture: Architecture.arm64,
        targetIOSSdk: IOSSdk.iPhoneOS,
        targetIOSVersion: 17,
        cCompiler: toolchain.cCompiler,
        check: (input, output) {
          final asset = output.assets.code.single;
          final libraryFile = File.fromUri(asset.file!);
          expect(libraryFile.existsSync(), isTrue);
          expect(libraryFile.uri.path, contains('ios-arm64-iphoneos'));
          expect(asset.file!.pathSegments.last, 'libtaglib_bridge.dylib');
          expect(input.config.code.iOS.targetSdk, IOSSdk.iPhoneOS);
        },
      );
    },
    skip: skipUnlessAppleHookToolchain(),
    timeout: buildHookTimeout,
  );
}

OS _hostTargetOS() {
  if (Platform.isWindows) {
    return OS.windows;
  }
  if (Platform.isMacOS) {
    return OS.macOS;
  }
  if (Platform.isLinux) {
    return OS.linux;
  }
  throw UnsupportedError(
    'Unsupported host OS for test: ${Platform.operatingSystem}',
  );
}

void _expectNoSharedLibCppDependency(Uri? readElf, File libraryFile) {
  if (readElf == null) {
    return;
  }

  final result = Process.runSync(
    readElf.toFilePath(windows: Platform.isWindows),
    <String>['--dynamic-table', libraryFile.path],
  );
  expect(
    result.exitCode,
    0,
    reason: 'llvm-readelf should inspect the Android library.',
  );
  final output = (result.stdout as Object?)?.toString() ?? '';
  expect(output, isNot(contains('c++_shared')));
}
