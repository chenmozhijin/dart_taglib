// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'backend_factory_io.dart'
    if (dart.library.js_interop) 'backend_factory_web.dart'
    as impl;
import 'taglib_backend.dart';

TaglibBackend createDefaultBackend({String? libraryPath}) {
  return impl.createDefaultBackend(libraryPath: libraryPath);
}
