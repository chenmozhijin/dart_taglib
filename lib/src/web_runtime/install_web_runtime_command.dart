// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'web_runtime_assets_io.dart';

Future<int> runInstallWebRuntimeCommand(
  List<String> arguments, {
  StringSink? stdoutSink,
  StringSink? stderrSink,
  Directory? currentDirectory,
  Directory? packageRoot,
}) async {
  final out = stdoutSink ?? stdout;
  final err = stderrSink ?? stderr;
  final parser = ArgParser()
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: taglibWebRuntimeDefaultOutput,
      help: 'Directory that will contain the runtime files.',
    )
    ..addFlag(
      'check',
      negatable: false,
      help: 'Check the output without changing files.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  late final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    err.writeln(error.message);
    err.writeln(parser.usage);
    return 64;
  }
  if (results.rest.isNotEmpty) {
    err.writeln('Unexpected arguments: ${results.rest.join(' ')}');
    err.writeln(parser.usage);
    return 64;
  }
  if (results.flag('help')) {
    out.writeln('Install the dart_taglib JavaScript/WebAssembly runtime.');
    out.writeln();
    out.writeln(parser.usage);
    return 0;
  }

  try {
    final resolvedPackageRoot = packageRoot ?? await _resolvePackageRoot();
    final manifest = await validateTaglibWebRuntimeSource(resolvedPackageRoot);
    final cwd = currentDirectory ?? Directory.current;
    final outputValue = results.option('output')!;
    final outputPath = p.isAbsolute(outputValue)
        ? p.normalize(outputValue)
        : p.normalize(p.join(cwd.path, outputValue));
    final outputDirectory = Directory(outputPath);

    if (results.flag('check')) {
      final issues = await inspectTaglibWebRuntimeDirectory(
        outputDirectory,
        manifest,
      );
      if (issues.isNotEmpty) {
        err.writeln('dart_taglib web runtime check failed:');
        for (final issue in issues) {
          err.writeln('  - $issue');
        }
        return 1;
      }
      out.writeln('dart_taglib web runtime is up to date: $outputPath');
      return 0;
    }

    final installResult = await installTaglibWebRuntime(
      packageRoot: resolvedPackageRoot,
      outputDirectory: outputDirectory,
    );
    out.writeln('dart_taglib web runtime installed: $outputPath');
    out.writeln('Updated: ${installResult.updated.length}');
    out.writeln('Unchanged: ${installResult.unchanged.length}');
    return 0;
  } on Object catch (error) {
    err.writeln(error);
    return 1;
  }
}

Future<Directory> _resolvePackageRoot() async {
  final libraryUri = await Isolate.resolvePackageUri(
    Uri.parse('package:dart_taglib/dart_taglib.dart'),
  );
  if (libraryUri == null || libraryUri.scheme != 'file') {
    throw StateError('Unable to resolve the dart_taglib package directory.');
  }
  return File.fromUri(libraryUri).parent.parent;
}
