// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'package:dart_taglib/src/ffi_native/native_backend.dart';
import 'package:test/test.dart';

void main() {
  test('maps native bridge fallback library names by operating system', () {
    expect(
      nativeBridgeLibraryFileNameForOperatingSystem('windows'),
      'taglib_bridge.dll',
    );
    expect(
      nativeBridgeLibraryFileNameForOperatingSystem('linux'),
      'libtaglib_bridge.so',
    );
    expect(
      nativeBridgeLibraryFileNameForOperatingSystem('android'),
      'libtaglib_bridge.so',
    );
    expect(
      nativeBridgeLibraryFileNameForOperatingSystem('macos'),
      'libtaglib_bridge.dylib',
    );
    expect(
      nativeBridgeLibraryFileNameForOperatingSystem('ios'),
      'libtaglib_bridge.dylib',
    );
  });

  test('rejects unsupported fallback operating systems', () {
    expect(
      () => nativeBridgeLibraryFileNameForOperatingSystem('fuchsia'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
