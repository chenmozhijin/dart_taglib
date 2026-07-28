// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

/// Origin of raw text bytes that may use a legacy charset.
enum TextIssueSource {
  /// An ID3v1 field.
  id3v1(1),

  /// A RIFF INFO field.
  riffInfo(2),

  /// An ID3v2 field declared as Latin-1.
  id3v2Latin1(3);

  /// Creates a source with the bridge ABI [nativeValue].
  const TextIssueSource(this.nativeValue);

  /// Numeric value used by the bridge.
  final int nativeValue;

  /// Maps a bridge ABI [value] to a known source.
  static TextIssueSource fromNative(int value) {
    return TextIssueSource.values.firstWhere(
      (item) => item.nativeValue == value,
      orElse: () => TextIssueSource.id3v2Latin1,
    );
  }
}

/// Evidence for a text field that may have been decoded incorrectly.
class TextIssue {
  /// Creates an issue while defensively copying [rawBytes] once.
  TextIssue({
    required this.source,
    required this.fieldPath,
    required this.frameId,
    required this.language,
    required this.description,
    required Uint8List rawBytes,
    required this.baselineDecoded,
  }) : rawBytes = Uint8List.fromList(rawBytes).asUnmodifiableView();

  /// Metadata container that produced the issue.
  final TextIssueSource source;

  /// Format-specific property path, when available.
  final String? fieldPath;

  /// ID3 frame identifier, when available.
  final String? frameId;

  /// Frame language, when available.
  final String? language;

  /// Frame description, when available.
  final String? description;

  /// Unmodifiable view of the copied original field bytes.
  final Uint8List rawBytes;

  /// Text produced by the bridge's baseline decoder.
  final String? baselineDecoded;
}
