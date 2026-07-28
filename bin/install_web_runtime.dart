// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:dart_taglib/src/web_runtime/install_web_runtime_command.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runInstallWebRuntimeCommand(arguments);
}
