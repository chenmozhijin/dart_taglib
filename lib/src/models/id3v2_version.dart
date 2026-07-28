// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// ID3v2 version used when saving MPEG metadata.
enum Id3v2Version {
  /// ID3v2.3.
  v23(3),

  /// ID3v2.4.
  v24(4);

  /// Creates a version with the bridge ABI [nativeValue].
  const Id3v2Version(this.nativeValue);

  /// Numeric version passed to the bridge.
  final int nativeValue;
}
