// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const String _taglibBridgeName = 'taglib_bridge';
const String _assetName = 'src/ffi_native/taglib_bridge_ffi.dart';

Future<void> runTaglibBridgeBuildHook(
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final plan = await createTaglibBridgeBuildPlan(input);

  // C++ 与 vendor 不属于 hook 的 Dart 依赖图，必须显式登记以防源码更新后复用旧二进制。
  output.dependencies.add(plan.nativeBridgeDirectory.uri);
  output.dependencies.add(plan.repoRoot.uri.resolve('third_party/taglib/'));

  plan.buildDirectory.createSync(recursive: true);

  await runCmake(
    plan.configureArguments,
    workingDirectory: plan.repoRoot.path,
    actionName: 'configure',
    environment: plan.environment,
  );
  await runCmake(
    plan.buildArguments,
    workingDirectory: plan.repoRoot.path,
    actionName: 'build',
    environment: plan.environment,
  );

  final dylibFile = resolveBuiltLibrary(
    buildDirectory: plan.buildDirectory,
    libraryFileName: plan.libraryFileName,
    isWindows: plan.targetOS == OS.windows,
  );

  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: _assetName,
      linkMode: DynamicLoadingBundled(),
      file: dylibFile.uri,
    ),
  );
}

Future<TaglibBridgeBuildPlan> createTaglibBridgeBuildPlan(
  BuildInput input,
) async {
  final config = input.config.code;
  ensureSupportedLinkModePreference(config.linkModePreference);
  ensureSupportedTargetOS(config.targetOS);
  ensureHostCanTarget(config.targetOS, hostOS: currentHostOS());

  final packageRoot = Directory.fromUri(input.packageRoot);
  final repoRoot = packageRoot;
  final nativeBridgeDirectory = Directory.fromUri(
    repoRoot.uri.resolve('native/taglib_bridge/'),
  );

  if (!nativeBridgeDirectory.existsSync()) {
    throw StateError(
      'native/taglib_bridge not found from ${repoRoot.path}. '
      'Expected the package root to also be the repository root.',
    );
  }

  final buildDirectory = Directory.fromUri(
    input.outputDirectoryShared.resolve(
      'taglib_bridge_build/'
      '${taglibBuildDirectoryName(config.targetOS, config.targetArchitecture, targetIOSSdk: config.targetOS == OS.iOS ? config.iOS.targetSdk : null)}/',
    ),
  );

  final environment = await resolveBuildEnvironment(config.cCompiler);
  final configureArguments = <String>[
    '-S',
    nativeBridgeDirectory.path,
    '-B',
    buildDirectory.path,
    '-DCMAKE_BUILD_TYPE=Release',
    ...configureToolchainArguments(config),
  ];

  return TaglibBridgeBuildPlan(
    repoRoot: repoRoot,
    nativeBridgeDirectory: nativeBridgeDirectory,
    buildDirectory: buildDirectory,
    targetOS: config.targetOS,
    targetArchitecture: config.targetArchitecture,
    libraryFileName: config.targetOS.dylibFileName(_taglibBridgeName),
    environment: environment,
    configureArguments: configureArguments,
    buildArguments: <String>[
      '--build',
      buildDirectory.path,
      '--clean-first',
      '--config',
      'Release',
    ],
  );
}

Future<Map<String, String>> resolveBuildEnvironment(
  CCompilerConfig? cCompiler,
) async {
  if (!Platform.isWindows || cCompiler?._windowsDeveloperPrompt == null) {
    return const <String, String>{};
  }

  final prompt = cCompiler!._windowsDeveloperPrompt!;
  return environmentFromBatchFile(prompt.script, arguments: prompt.arguments);
}

List<String> configureToolchainArguments(CodeConfig config) {
  final result = <String>[];
  final cCompiler = config.cCompiler;

  if (cCompiler != null) {
    result.addAll(<String>[
      '-DCMAKE_C_COMPILER=${cCompiler.compiler.toFilePath(windows: Platform.isWindows)}',
      '-DCMAKE_CXX_COMPILER=${deriveCppCompilerUri(cCompiler.compiler).toFilePath(windows: Platform.isWindows)}',
      '-DCMAKE_AR=${cCompiler.archiver.toFilePath(windows: Platform.isWindows)}',
      '-DCMAKE_LINKER=${cCompiler.linker.toFilePath(windows: Platform.isWindows)}',
    ]);
  }

  switch (config.targetOS) {
    case OS.android:
      final compiler = cCompiler?.compiler;
      if (compiler == null) {
        throw StateError(
          'Android builds require input.config.code.cCompiler to be set.',
        );
      }
      final ndkRoot = findAndroidNdkRoot(compiler);
      final ninjaPath = findAndroidSdkNinja(ndkRoot);
      result.addAll(<String>[
        '-G',
        'Ninja',
        if (ninjaPath != null)
          '-DCMAKE_MAKE_PROGRAM=${ninjaPath.toFilePath(windows: Platform.isWindows)}',
        '-DCMAKE_TOOLCHAIN_FILE=${ndkRoot.resolve('build/cmake/android.toolchain.cmake').toFilePath(windows: Platform.isWindows)}',
        '-DANDROID_ABI=${androidAbiForArchitecture(config.targetArchitecture)}',
        '-DANDROID_PLATFORM=android-${config.android.targetNdkApi}',
        '-DANDROID_STL=c++_static',
        '-DCMAKE_SYSTEM_NAME=Android',
        '-DCMAKE_SYSTEM_PROCESSOR=${cmakeSystemProcessorForArchitecture(config.targetArchitecture)}',
        '-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY',
      ]);
    case OS.iOS:
      if (!Platform.isMacOS) {
        throw UnsupportedError('iOS builds require a macOS host with Xcode.');
      }
      final iosSdk = config.iOS.targetSdk;
      result.addAll(<String>[
        '-DCMAKE_SYSTEM_NAME=iOS',
        '-DCMAKE_OSX_SYSROOT=${resolveAppleSdkPath(iosSdk)}',
        '-DCMAKE_OSX_ARCHITECTURES=${appleArchitectureFor(config.targetArchitecture, targetOS: config.targetOS)}',
        '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.iOS.targetVersion}',
        '-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY',
      ]);
    case OS.macOS:
      result.addAll(<String>[
        '-DCMAKE_SYSTEM_NAME=Darwin',
        '-DCMAKE_OSX_ARCHITECTURES=${appleArchitectureFor(config.targetArchitecture, targetOS: config.targetOS)}',
        '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.macOS.targetVersion}',
      ]);
    case OS.linux:
      result.addAll(<String>[
        '-DCMAKE_SYSTEM_NAME=Linux',
        '-DCMAKE_SYSTEM_PROCESSOR=${cmakeSystemProcessorForArchitecture(config.targetArchitecture)}',
      ]);
    case OS.windows:
      final generatorPlatform = tryWindowsGeneratorPlatformForArchitecture(
        config.targetArchitecture,
      );
      if (_shouldSetWindowsGeneratorPlatform(generatorPlatform)) {
        result.addAll(<String>['-A', generatorPlatform!]);
      }
      result.addAll(<String>[
        '-DCMAKE_SYSTEM_NAME=Windows',
        '-DCMAKE_SYSTEM_PROCESSOR=${cmakeSystemProcessorForArchitecture(config.targetArchitecture)}',
      ]);
    case OS.fuchsia:
      throw UnsupportedError(
        'Unsupported target OS for taglib_bridge: ${config.targetOS}',
      );
  }

  return result;
}

void ensureSupportedLinkModePreference(LinkModePreference preference) {
  if (preference == LinkModePreference.dynamic ||
      preference == LinkModePreference.preferDynamic) {
    return;
  }

  throw UnsupportedError(
    'taglib_bridge only supports dynamic native assets today. '
    'Static link mode preference "$preference" is not supported because '
    'StaticLinking is not yet supported by the Dart/Flutter SDK for code_assets.',
  );
}

void ensureSupportedTargetOS(OS os) {
  if (supportedTargetOS.contains(os)) {
    return;
  }
  throw UnsupportedError('Unsupported target OS for taglib_bridge: $os');
}

void ensureHostCanTarget(OS targetOS, {required OS hostOS}) {
  if (supportedHostTargets[hostOS]?.contains(targetOS) ?? false) {
    return;
  }
  throw UnsupportedError(
    'Host "$hostOS" cannot build taglib_bridge for target "$targetOS".',
  );
}

const List<OS> supportedTargetOS = <OS>[
  OS.windows,
  OS.linux,
  OS.macOS,
  OS.android,
  OS.iOS,
];

const Map<OS, List<OS>> supportedHostTargets = <OS, List<OS>>{
  OS.windows: <OS>[OS.windows, OS.android],
  OS.linux: <OS>[OS.linux, OS.android],
  OS.macOS: <OS>[OS.macOS, OS.iOS, OS.android],
};

OS currentHostOS() {
  if (Platform.isWindows) {
    return OS.windows;
  }
  if (Platform.isMacOS) {
    return OS.macOS;
  }
  if (Platform.isLinux) {
    return OS.linux;
  }
  throw UnsupportedError('Unsupported host OS: ${Platform.operatingSystem}');
}

String taglibBuildDirectoryName(
  OS os,
  Architecture architecture, {
  IOSSdk? targetIOSSdk,
}) {
  final suffix = switch (os) {
    OS.iOS when targetIOSSdk != null => '-${targetIOSSdk.type}',
    _ => '',
  };
  return '${os.name}-${architecture.name}$suffix';
}

String androidAbiForArchitecture(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm => 'armeabi-v7a',
    Architecture.arm64 => 'arm64-v8a',
    Architecture.ia32 => 'x86',
    Architecture.x64 => 'x86_64',
    Architecture.riscv64 => 'riscv64',
    _ => throw UnsupportedError(
      'Unsupported Android architecture for taglib_bridge: $architecture',
    ),
  };
}

String appleArchitectureFor(Architecture architecture, {required OS targetOS}) {
  return switch (architecture) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x86_64',
    _ => throw UnsupportedError(
      'Unsupported Apple architecture for $targetOS: $architecture',
    ),
  };
}

String cmakeSystemProcessorForArchitecture(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm => 'armv7',
    Architecture.arm64 => 'arm64',
    Architecture.ia32 => 'x86',
    Architecture.x64 => 'x86_64',
    Architecture.riscv32 => 'riscv32',
    Architecture.riscv64 => 'riscv64',
    _ => throw UnsupportedError(
      'Unsupported architecture for CMake system processor: $architecture',
    ),
  };
}

String? tryWindowsGeneratorPlatformForArchitecture(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm64 => 'ARM64',
    Architecture.ia32 => 'Win32',
    Architecture.x64 => 'x64',
    _ => null,
  };
}

bool _shouldSetWindowsGeneratorPlatform(String? generatorPlatform) {
  if (!Platform.isWindows || generatorPlatform == null) {
    return false;
  }

  final configuredGenerator = Platform.environment['CMAKE_GENERATOR'];
  return configuredGenerator == null ||
      configuredGenerator.startsWith('Visual Studio');
}

Uri deriveCppCompilerUri(Uri cCompiler) {
  final compilerFile = File.fromUri(cCompiler);
  final compilerName = compilerFile.uri.pathSegments.last;
  final lowerName = compilerName.toLowerCase();
  final directory = compilerFile.parent.uri;

  if (lowerName == 'cl.exe' || lowerName == 'cl') {
    return cCompiler;
  }
  if (lowerName == 'clang-cl.exe' || lowerName == 'clang-cl') {
    return cCompiler;
  }

  final siblingName = switch (true) {
    _ when lowerName.endsWith('clang.exe') =>
      '${compilerName.substring(0, compilerName.length - 'clang.exe'.length)}clang++.exe',
    _ when lowerName.endsWith('clang') =>
      '${compilerName.substring(0, compilerName.length - 'clang'.length)}clang++',
    _ when lowerName.endsWith('gcc.exe') =>
      '${compilerName.substring(0, compilerName.length - 'gcc.exe'.length)}g++.exe',
    _ when lowerName.endsWith('gcc') =>
      '${compilerName.substring(0, compilerName.length - 'gcc'.length)}g++',
    _ when lowerName.endsWith('cc.exe') =>
      '${compilerName.substring(0, compilerName.length - 'cc.exe'.length)}c++.exe',
    _ when lowerName.endsWith('cc') =>
      '${compilerName.substring(0, compilerName.length - 'cc'.length)}c++',
    _ => null,
  };

  if (siblingName == null) {
    throw StateError(
      'Unable to derive a C++ compiler sibling from "${compilerFile.path}".',
    );
  }

  final siblingUri = directory.resolve(siblingName);
  if (!File.fromUri(siblingUri).existsSync()) {
    throw StateError(
      'Derived C++ compiler not found at "${File.fromUri(siblingUri).path}" '
      'for C compiler "${compilerFile.path}".',
    );
  }

  return siblingUri;
}

Uri findAndroidNdkRoot(Uri compilerUri) {
  Directory? current = File.fromUri(compilerUri).parent;
  while (current != null) {
    final toolchainDir = Directory.fromUri(
      current.uri.resolve('toolchains/llvm/prebuilt/'),
    );
    if (toolchainDir.existsSync()) {
      return current.uri;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }

  throw StateError(
    'Unable to locate Android NDK root from compiler '
    '"${File.fromUri(compilerUri).path}".',
  );
}

Uri? findAndroidSdkNinja(Uri ndkRoot) {
  final explicitMakeProgram = Platform.environment['CMAKE_MAKE_PROGRAM'];
  if (explicitMakeProgram != null && explicitMakeProgram.trim().isNotEmpty) {
    return Uri.file(explicitMakeProgram.trim(), windows: Platform.isWindows);
  }

  final ndkDirectory = Directory.fromUri(ndkRoot);
  final sdkDirectory = ndkDirectory.parent.parent;
  final cmakeDirectory = Directory.fromUri(sdkDirectory.uri.resolve('cmake/'));
  if (!cmakeDirectory.existsSync()) {
    return null;
  }

  final candidates = <_AndroidSdkNinjaCandidate>[];
  for (final directory in cmakeDirectory.listSync(followLinks: false)) {
    if (directory is! Directory) {
      continue;
    }
    final ninja = File.fromUri(directory.uri.resolve('bin/ninja.exe'));
    if (!ninja.existsSync()) {
      continue;
    }
    final version = _SemanticVersion.tryParse(
      directory.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
    );
    if (version == null) {
      continue;
    }
    candidates.add(_AndroidSdkNinjaCandidate(version: version, file: ninja));
  }
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort((left, right) => right.version.compareTo(left.version));
  return candidates.first.file.uri;
}

final class _AndroidSdkNinjaCandidate {
  const _AndroidSdkNinjaCandidate({required this.version, required this.file});

  final _SemanticVersion version;
  final File file;
}

final class _SemanticVersion implements Comparable<_SemanticVersion> {
  const _SemanticVersion(this.parts);

  final List<int> parts;

  static _SemanticVersion? tryParse(String value) {
    final parts = <int>[];
    for (final piece in value.split('.')) {
      final match = RegExp(r'^\d+').firstMatch(piece);
      if (match == null) {
        return null;
      }
      parts.add(int.parse(match.group(0)!));
    }
    if (parts.isEmpty) {
      return null;
    }
    return _SemanticVersion(List<int>.unmodifiable(parts));
  }

  @override
  int compareTo(_SemanticVersion other) {
    final maxLength = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < maxLength; i++) {
      final left = i < parts.length ? parts[i] : 0;
      final right = i < other.parts.length ? other.parts[i] : 0;
      if (left != right) {
        return left.compareTo(right);
      }
    }
    return 0;
  }
}

String resolveAppleSdkPath(IOSSdk sdk) {
  final result = Process.runSync('xcrun', <String>[
    '--sdk',
    sdk.type,
    '--show-sdk-path',
  ]);
  if (result.exitCode != 0) {
    final stderrText = (result.stderr as Object?)?.toString() ?? '';
    throw StateError(
      'Failed to resolve Apple SDK path for "${sdk.type}".\n$stderrText',
    );
  }

  final path = (result.stdout as Object?)?.toString().trim() ?? '';
  if (path.isEmpty) {
    throw StateError('xcrun returned an empty SDK path for "${sdk.type}".');
  }
  return path;
}

File resolveBuiltLibrary({
  required Directory buildDirectory,
  required String libraryFileName,
  required bool isWindows,
}) {
  final candidates = <File>[
    File.fromUri(buildDirectory.uri.resolve('Release/$libraryFileName')),
    File.fromUri(buildDirectory.uri.resolve(libraryFileName)),
  ];

  if (isWindows) {
    candidates.add(
      File.fromUri(
        buildDirectory.uri.resolve('RelWithDebInfo/$libraryFileName'),
      ),
    );
    candidates.add(
      File.fromUri(buildDirectory.uri.resolve('MinSizeRel/$libraryFileName')),
    );
  }

  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }

  final listed = candidates.map((file) => file.path).join('\n');
  throw StateError('Built library not found. Checked:\n$listed');
}

Future<void> runCmake(
  List<String> arguments, {
  required String workingDirectory,
  required String actionName,
  Map<String, String> environment = const <String, String>{},
}) async {
  final result = await Process.run(
    'cmake',
    arguments,
    workingDirectory: workingDirectory,
    environment: environment.isEmpty ? null : environment,
  );

  if (result.exitCode == 0) {
    return;
  }

  final stderrText = (result.stderr as Object?)?.toString() ?? '';
  final stdoutText = (result.stdout as Object?)?.toString() ?? '';
  throw StateError(
    'cmake $actionName failed (${result.exitCode}).\n'
    'args: ${arguments.join(' ')}\n'
    'stdout:\n$stdoutText\n'
    'stderr:\n$stderrText',
  );
}

final class TaglibBridgeBuildPlan {
  TaglibBridgeBuildPlan({
    required this.repoRoot,
    required this.nativeBridgeDirectory,
    required this.buildDirectory,
    required this.targetOS,
    required this.targetArchitecture,
    required this.libraryFileName,
    required this.environment,
    required this.configureArguments,
    required this.buildArguments,
  });

  final Directory repoRoot;
  final Directory nativeBridgeDirectory;
  final Directory buildDirectory;
  final OS targetOS;
  final Architecture targetArchitecture;
  final String libraryFileName;
  final Map<String, String> environment;
  final List<String> configureArguments;
  final List<String> buildArguments;
}

extension on CCompilerConfig {
  DeveloperCommandPrompt? get _windowsDeveloperPrompt {
    try {
      return windows.developerCommandPrompt;
    } on StateError {
      return null;
    }
  }
}
