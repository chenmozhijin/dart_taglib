// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'basic_tags.dart';
import 'text_issue.dart';

/// The final value and repair evidence for one text field.
class RepairedTextValue {
  /// Creates an immutable field result.
  const RepairedTextValue({
    required this.value,
    this.detectedEncoding,
    required this.confidence,
    required this.repaired,
    required this.uncertain,
  });

  /// Selected decoded value, or null when the field is absent.
  final String? value;

  /// Detected encoding name, when detection produced a candidate.
  final String? detectedEncoding;

  /// Detection confidence in the inclusive range from 0 to 1.
  final double confidence;

  /// Whether [value] differs from the bridge's baseline decoding.
  final bool repaired;

  /// Whether no candidate met the requested confidence threshold.
  final bool uncertain;
}

/// Basic tags together with per-field repair evidence and source issues.
class ReadTagsResult {
  /// Creates a result with unmodifiable copies of [fields] and [issues].
  ReadTagsResult({
    required this.tags,
    required Map<String, RepairedTextValue> fields,
    required List<TextIssue> issues,
  }) : fields = Map<String, RepairedTextValue>.unmodifiable(fields),
       issues = List<TextIssue>.unmodifiable(issues);

  /// Final tags after any accepted repairs.
  final BasicTags tags;

  /// Repair evidence keyed by basic field name.
  final Map<String, RepairedTextValue> fields;

  /// Unmodifiable encoding issues reported by the bridge.
  final List<TextIssue> issues;
}
