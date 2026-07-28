// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List> fetchBrowserBytes(String path) async {
  final response = await web.window.fetch(path.toJS).toDart;
  if (!response.ok) {
    throw StateError('Failed to fetch $path: HTTP ${response.status}');
  }
  final buffer = await response.arrayBuffer().toDart;
  return Uint8List.view(buffer.toDart);
}
