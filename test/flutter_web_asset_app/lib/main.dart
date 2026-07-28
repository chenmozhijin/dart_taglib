// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'package:dart_taglib/dart_taglib.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  await initializeTaglibWasmBridge();
  final title = const BasicTags(title: 'dart_taglib').title!;
  runApp(Directionality(textDirection: TextDirection.ltr, child: Text(title)));
}
