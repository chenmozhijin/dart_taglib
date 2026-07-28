// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import '../wasm_web/wasm_backend.dart';
import 'taglib_backend.dart';

TaglibBackend createDefaultBackend({String? libraryPath}) {
  if (libraryPath != null && libraryPath.isNotEmpty) {
    throw UnsupportedError(
      'libraryPath is only supported by the native backend. '
      'On Web, initialize the runtime with initializeTaglibWasmBridge(...).',
    );
  }
  return WasmTaglibBackend();
}
