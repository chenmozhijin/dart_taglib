// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('browser')
library;

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

void main() {
  test('failed script load can retry from a valid asset directory', () async {
    await expectLater(
      initializeTaglibWasmBridge(assetBaseUrl: 'missing_web_runtime/'),
      throwsA(isA<StateError>()),
    );

    await initializeTaglibWasmBridge();
    expect(hasTaglibWasmBridge(), isTrue);
  });
}
