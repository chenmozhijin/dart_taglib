// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

/// An embedded picture and its optional metadata.
class PictureItem {
  /// Creates a picture while defensively copying [data] once.
  PictureItem({
    required Uint8List data,
    this.mimeType,
    this.description,
    this.pictureType,
  }) : data = Uint8List.fromList(data).asUnmodifiableView();

  /// MIME type such as `image/jpeg`.
  final String? mimeType;

  /// Human-readable picture description.
  final String? description;

  /// TagLib picture type name or value.
  final String? pictureType;

  /// Unmodifiable view of the copied picture bytes.
  final Uint8List data;
}

/// A native picture input that is read directly from a local file.
///
/// This avoids first copying the complete image into both the Dart heap and an
/// FFI input buffer. It is not supported on Web.
class PictureFileItem {
  /// Creates a local picture input.
  const PictureFileItem({
    required this.path,
    this.mimeType,
    this.description,
    this.pictureType,
  });

  /// Local path of the image file.
  final String path;

  /// MIME type such as `image/png`.
  final String? mimeType;

  /// Human-readable picture description.
  final String? description;

  /// TagLib picture type name or value.
  final String? pictureType;
}
