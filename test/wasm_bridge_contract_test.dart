// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

void main() {
  test('non-web platform exposes wasm stub', () {
    expect(hasTaglibWasmBridge(), isFalse);
    expect(initializeTaglibWasmBridge, throwsA(isA<UnsupportedError>()));
    expect(
      taglibWasmDefaultAssetBaseUrl,
      'assets/packages/dart_taglib/web_runtime/',
    );
  });
}
