// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import 'package:dart_taglib/src/hook/build_support.dart' as build_support;

void main() {
  group('build support helpers', () {
    test('accepts dynamic link mode preferences only', () {
      expect(
        () => build_support.ensureSupportedLinkModePreference(
          LinkModePreference.dynamic,
        ),
        returnsNormally,
      );
      expect(
        () => build_support.ensureSupportedLinkModePreference(
          LinkModePreference.preferDynamic,
        ),
        returnsNormally,
      );
      expect(
        () => build_support.ensureSupportedLinkModePreference(
          LinkModePreference.static,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => build_support.ensureSupportedLinkModePreference(
          LinkModePreference.preferStatic,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('maps Android architectures to ABIs', () {
      expect(
        build_support.androidAbiForArchitecture(Architecture.arm),
        'armeabi-v7a',
      );
      expect(
        build_support.androidAbiForArchitecture(Architecture.arm64),
        'arm64-v8a',
      );
      expect(build_support.androidAbiForArchitecture(Architecture.ia32), 'x86');
      expect(
        build_support.androidAbiForArchitecture(Architecture.x64),
        'x86_64',
      );
      expect(
        build_support.androidAbiForArchitecture(Architecture.riscv64),
        'riscv64',
      );
    });

    test('computes build directory names for native targets', () {
      expect(
        build_support.taglibBuildDirectoryName(OS.android, Architecture.arm64),
        'android-arm64',
      );
      expect(
        build_support.taglibBuildDirectoryName(
          OS.iOS,
          Architecture.x64,
          targetIOSSdk: IOSSdk.iPhoneSimulator,
        ),
        'ios-x64-iphonesimulator',
      );
    });

    test('validates host and target compatibility', () {
      expect(
        () => build_support.ensureHostCanTarget(OS.android, hostOS: OS.windows),
        returnsNormally,
      );
      expect(
        () => build_support.ensureHostCanTarget(OS.iOS, hostOS: OS.macOS),
        returnsNormally,
      );
      expect(
        () => build_support.ensureHostCanTarget(OS.iOS, hostOS: OS.windows),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('maps Windows generator platforms', () {
      expect(
        build_support.tryWindowsGeneratorPlatformForArchitecture(
          Architecture.arm64,
        ),
        'ARM64',
      );
      expect(
        build_support.tryWindowsGeneratorPlatformForArchitecture(
          Architecture.ia32,
        ),
        'Win32',
      );
      expect(
        build_support.tryWindowsGeneratorPlatformForArchitecture(
          Architecture.x64,
        ),
        'x64',
      );
      expect(
        build_support.tryWindowsGeneratorPlatformForArchitecture(
          Architecture.arm,
        ),
        isNull,
      );
    });

    test('derives C++ compiler path from clang sibling', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_taglib_build_support',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final clang = File.fromUri(tempDir.uri.resolve('clang'))..createSync();
      final clangxx = File.fromUri(tempDir.uri.resolve('clang++'))
        ..createSync();

      expect(build_support.deriveCppCompilerUri(clang.uri), clangxx.uri);
    });

    test(
      'preserves compiler prefixes when deriving clang++ siblings',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'dart_taglib_build_support_prefixed',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final clang = File.fromUri(
          tempDir.uri.resolve('aarch64-linux-android-clang'),
        )..createSync();
        final clangxx = File.fromUri(
          tempDir.uri.resolve('aarch64-linux-android-clang++'),
        )..createSync();

        expect(build_support.deriveCppCompilerUri(clang.uri), clangxx.uri);
      },
    );

    test('reuses cl.exe as the C++ compiler on Windows toolchains', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_taglib_build_support_cl',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final cl = File.fromUri(tempDir.uri.resolve('cl.exe'))..createSync();
      expect(build_support.deriveCppCompilerUri(cl.uri), cl.uri);
    });

    test('finds Android NDK roots from compiler locations', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_taglib_ndk_root',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final ndkRoot = Directory.fromUri(tempDir.uri.resolve('android-ndk/'));
      Directory.fromUri(
        ndkRoot.uri.resolve('toolchains/llvm/prebuilt/host/bin/'),
      ).createSync(recursive: true);
      final compiler = File.fromUri(
        ndkRoot.uri.resolve('toolchains/llvm/prebuilt/host/bin/clang'),
      )..createSync();

      expect(build_support.findAndroidNdkRoot(compiler.uri), ndkRoot.uri);
    });

    test('chooses highest semantic Android SDK CMake ninja', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_taglib_android_ninja',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final sdkDir = Directory.fromUri(tempDir.uri.resolve('sdk/'));
      final ndkRoot = Directory.fromUri(sdkDir.uri.resolve('ndk/26.0.0/'))
        ..createSync(recursive: true);
      for (final version in <String>['3.9', '3.22.1', '3.10.2']) {
        final binDir = Directory.fromUri(
          sdkDir.uri.resolve('cmake/$version/bin/'),
        )..createSync(recursive: true);
        File.fromUri(binDir.uri.resolve('ninja.exe')).createSync();
      }

      final ninja = build_support.findAndroidSdkNinja(ndkRoot.uri);

      expect(ninja?.path, contains('3.22.1'));
    });
    test('resolves built libraries from common CMake output folders', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_taglib_build_output',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final releaseDirectory = Directory.fromUri(
        tempDir.uri.resolve('Release/'),
      )..createSync(recursive: true);
      final libraryFile = File.fromUri(
        releaseDirectory.uri.resolve('libtaglib_bridge.so'),
      )..createSync();

      expect(
        build_support
            .resolveBuiltLibrary(
              buildDirectory: tempDir,
              libraryFileName: 'libtaglib_bridge.so',
              isWindows: false,
            )
            .path,
        libraryFile.path,
      );
    });
  });
}
