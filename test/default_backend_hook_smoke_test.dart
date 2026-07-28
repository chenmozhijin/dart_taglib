// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

void main() {
  test(
    'default backend resolves bundled native asset without explicit path',
    () {
      final api = TaglibApi();
      expect(() {
        try {
          final session = api.openSession(
            Uint8List.fromList(const <int>[1, 2, 3, 4]),
            nameHint: 'invalid.mp3',
          );
          session.close();
        } on TaglibException {
          // A bridge-level status error still proves the native asset was
          // loaded and called.
        }
      }, returnsNormally);
    },
  );
}
