// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_normalizer_dart/charset_normalizer_dart.dart'
    as charset_normalizer;

import '../models/basic_tags.dart';
import '../models/read_tags_result.dart';
import '../models/text_issue.dart';

/// A decoded text candidate returned by a [CharsetDetector].
class CharsetDetection {
  /// Creates a detection result.
  const CharsetDetection({
    required this.encoding,
    required this.confidence,
    required this.decoded,
  });

  /// Canonical or detector-provided encoding name.
  final String encoding;

  /// Detector confidence in the inclusive range from 0 to 1.
  final double confidence;

  /// Text decoded using [encoding].
  final String decoded;
}

/// Detects and decodes the character encoding of a byte sequence.
abstract interface class CharsetDetector {
  /// Returns the best candidate for [bytes], or null when none is reliable.
  CharsetDetection? detect(Uint8List bytes, {List<String>? preferredCharsets});
}

/// Charset detector backed by `package:charset_normalizer_dart`.
class CharsetNormalizerDetector implements CharsetDetector {
  /// Creates the default stateless detector.
  const CharsetNormalizerDetector();

  /// Detects [bytes], optionally restricting candidates to
  /// [preferredCharsets].
  @override
  CharsetDetection? detect(Uint8List bytes, {List<String>? preferredCharsets}) {
    if (bytes.isEmpty) {
      return const CharsetDetection(
        encoding: 'utf-8',
        confidence: 1.0,
        decoded: '',
      );
    }

    final matches = charset_normalizer.fromBytes(
      bytes,
      cpIsolation: preferredCharsets,
    );
    final best = matches.best();
    if (best == null) {
      return null;
    }

    return CharsetDetection(
      encoding: best.encoding,
      confidence: (1.0 - best.chaos).clamp(0.0, 1.0).toDouble(),
      decoded: best.toString(),
    );
  }
}

/// Repairs metadata fields for which the bridge retained suspicious raw bytes.
class DirtyTextRepairEngine {
  /// Creates an engine using [detector], or [CharsetNormalizerDetector] when
  /// omitted.
  DirtyTextRepairEngine({CharsetDetector? detector})
    : _detector = detector ?? const CharsetNormalizerDetector();

  final CharsetDetector _detector;

  /// Applies the best reliable repair candidate to [rawTags].
  ///
  /// [confidenceThreshold] must be finite and between 0 and 1. Every original
  /// [TextIssue] is retained in the result, including fields that remain
  /// uncertain or unchanged.
  ReadTagsResult repair({
    required BasicTags rawTags,
    required List<TextIssue> issues,
    required List<String>? preferredCharsets,
    required double confidenceThreshold,
  }) {
    _validateConfidenceThreshold(confidenceThreshold);

    var tags = rawTags;
    final fields = _rawFieldMap(rawTags);
    final issueSeen = <String>{};

    for (final issue in issues) {
      final fieldKey = _fieldKeyFromIssue(issue);
      if (fieldKey == null) {
        continue;
      }

      final baseline = issue.baselineDecoded ?? _fallbackDecode(issue.rawBytes);
      CharsetDetection? detection;
      Object? detectionError;
      try {
        detection = _detector.detect(
          issue.rawBytes,
          preferredCharsets: preferredCharsets,
        );
      } on Object catch (error) {
        detectionError = error;
      }

      final confidence = detection?.confidence ?? 0.0;
      final decoded = detection?.decoded ?? baseline;
      final uncertain =
          detectionError != null ||
          detection == null ||
          confidence < confidenceThreshold;
      final repaired = !uncertain && decoded != baseline;
      final value = repaired ? decoded : baseline;

      final nextValue = RepairedTextValue(
        value: value,
        detectedEncoding: detection?.encoding,
        confidence: confidence,
        repaired: repaired,
        uncertain: uncertain,
      );

      final current = fields[fieldKey];
      if (!issueSeen.contains(fieldKey) ||
          _isBetterCandidate(nextValue, current)) {
        issueSeen.add(fieldKey);
        fields[fieldKey] = nextValue;
        if (repaired) {
          tags = _applyField(tags, fieldKey, value);
        }
      }
    }

    return ReadTagsResult(tags: tags, fields: fields, issues: issues);
  }

  static void _validateConfidenceThreshold(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'confidenceThreshold');
    }
  }

  static bool _isBetterCandidate(
    RepairedTextValue next,
    RepairedTextValue? current,
  ) {
    if (current == null) {
      return true;
    }
    if (next.repaired != current.repaired) {
      return next.repaired;
    }
    if (next.uncertain != current.uncertain) {
      return !next.uncertain;
    }
    return next.confidence > current.confidence;
  }

  static String _fallbackDecode(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } on Object {
      return latin1.decode(bytes);
    }
  }

  static Map<String, RepairedTextValue> _rawFieldMap(BasicTags tags) {
    return <String, RepairedTextValue>{
      'title': RepairedTextValue(
        value: tags.title,
        confidence: 1.0,
        repaired: false,
        uncertain: false,
      ),
      'artist': RepairedTextValue(
        value: tags.artist,
        confidence: 1.0,
        repaired: false,
        uncertain: false,
      ),
      'album': RepairedTextValue(
        value: tags.album,
        confidence: 1.0,
        repaired: false,
        uncertain: false,
      ),
      'comment': RepairedTextValue(
        value: tags.comment,
        confidence: 1.0,
        repaired: false,
        uncertain: false,
      ),
      'genre': RepairedTextValue(
        value: tags.genre,
        confidence: 1.0,
        repaired: false,
        uncertain: false,
      ),
      'lyrics': RepairedTextValue(
        value: tags.lyrics,
        confidence: 1.0,
        repaired: false,
        uncertain: false,
      ),
    };
  }

  String? _fieldKeyFromIssue(TextIssue issue) {
    final frameId = issue.frameId?.toUpperCase();
    switch (frameId) {
      case 'TIT2':
        return 'title';
      case 'TPE1':
        return 'artist';
      case 'TALB':
        return 'album';
      case 'TCON':
        return 'genre';
      case 'COMM':
        return 'comment';
      case 'USLT':
      case 'SYLT':
        return 'lyrics';
    }

    final path = issue.fieldPath ?? '';
    if (path.startsWith('id3v1.')) {
      if (path.endsWith('title')) return 'title';
      if (path.endsWith('artist')) return 'artist';
      if (path.endsWith('album')) return 'album';
      if (path.endsWith('comment')) return 'comment';
      if (path.endsWith('genre')) return 'genre';
    }

    if (path.startsWith('riff.info.')) {
      final key = path.substring('riff.info.'.length).toUpperCase();
      switch (key) {
        case 'INAM':
          return 'title';
        case 'IART':
          return 'artist';
        case 'IPRD':
          return 'album';
        case 'ICMT':
          return 'comment';
        case 'IGNR':
          return 'genre';
        case 'ILYR':
          return 'lyrics';
      }
    }

    return null;
  }

  BasicTags _applyField(BasicTags tags, String fieldKey, String value) {
    switch (fieldKey) {
      case 'title':
        return tags.copyWith(title: value);
      case 'artist':
        return tags.copyWith(artist: value);
      case 'album':
        return tags.copyWith(album: value);
      case 'comment':
        return tags.copyWith(comment: value);
      case 'genre':
        return tags.copyWith(genre: value);
      case 'lyrics':
        return tags.copyWith(lyrics: value);
      default:
        return tags;
    }
  }
}
