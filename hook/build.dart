// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:dart_taglib/src/web_runtime/web_runtime_assets_io.dart';
import 'package:hooks/hooks.dart';

import 'package:dart_taglib/src/hook/build_support.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    output.dependencies.addAll(
      taglibWebRuntimeDependencyUris(input.packageRoot),
    );
    await validateTaglibWebRuntimeSource(Directory.fromUri(input.packageRoot));

    if (!input.config.buildCodeAssets) {
      return;
    }

    await runTaglibBridgeBuildHook(input, output);
  });
}
