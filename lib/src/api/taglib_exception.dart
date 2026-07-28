// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// An error reported by the native or WebAssembly TagLib bridge.
class TaglibException implements Exception {
  /// Creates an exception with the bridge [statusCode] and readable [message].
  TaglibException(this.statusCode, this.message);

  /// Numeric status returned by the bridge ABI.
  final int statusCode;

  /// Human-readable description of the failed operation.
  final String message;

  @override
  String toString() => 'TaglibException($statusCode): $message';
}
