// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import '../backend/taglib_backend.dart';
import 'wasm_runtime_config.dart';

/// Initializes the packaged TagLib WebAssembly runtime in a browser.
///
/// Flutter Web bundles the runtime at [taglibWasmDefaultAssetBaseUrl]. Pure
/// Dart Web applications can install the same layout with
/// `dart run dart_taglib:install_web_runtime`.
///
/// Throws [UnsupportedError] outside a browser.
Future<void> initializeTaglibWasmBridge({
  String assetBaseUrl = taglibWasmDefaultAssetBaseUrl,
  Object? moduleOptions,
}) {
  throw UnsupportedError('Wasm bridge is only available on web platform.');
}

/// Whether the TagLib WebAssembly bridge has completed initialization.
bool hasTaglibWasmBridge() => false;

/// TagLib backend that delegates operations to the initialized WebAssembly
/// bridge.
final class WasmTaglibBackend implements TaglibBackend {
  /// Creates a backend on Web and throws [UnsupportedError] elsewhere.
  WasmTaglibBackend();

  UnsupportedError _unsupported() =>
      UnsupportedError('Wasm backend is only available on web platform.');

  @override
  TaglibSessionBackend openSession(Uint8List bytes, {String? nameHint}) =>
      throw _unsupported();
}
