// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import '../ffi_native/native_backend.dart';
import 'taglib_backend.dart';

TaglibBackend createDefaultBackend({String? libraryPath}) {
  return NativeTaglibBackend(libraryPath: libraryPath);
}
