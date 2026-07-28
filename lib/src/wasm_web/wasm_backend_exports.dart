// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

export 'wasm_backend_stub.dart'
    if (dart.library.js_interop) 'wasm_backend.dart';
export 'wasm_runtime_config.dart';
