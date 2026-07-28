// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

class _FakeDetector implements CharsetDetector {
  const _FakeDetector({
    required this.encoding,
    required this.confidence,
    required this.decoded,
  });

  final String encoding;
  final double confidence;
  final String decoded;

  @override
  CharsetDetection? detect(Uint8List bytes, {List<String>? preferredCharsets}) {
    return CharsetDetection(
      encoding: encoding,
      confidence: confidence,
      decoded: decoded,
    );
  }
}

void main() {
  mainDirtyTextRepairB13();
  test('repairs field when confidence is high enough', () {
    final engine = DirtyTextRepairEngine(
      detector: const _FakeDetector(
        encoding: 'gbk',
        confidence: 0.95,
        decoded: '修复后的标题',
      ),
    );

    final rawTags = const BasicTags(title: 'ÀÞ¸è');
    final issues = <TextIssue>[
      TextIssue(
        source: TextIssueSource.id3v2Latin1,
        fieldPath: 'id3v2.TIT2[0]',
        frameId: 'TIT2',
        language: null,
        description: null,
        rawBytes: Uint8List.fromList(const <int>[0xc0, 0xde, 0xb8, 0xe8]),
        baselineDecoded: 'ÀÞ¸è',
      ),
    ];

    final result = engine.repair(
      rawTags: rawTags,
      issues: issues,
      preferredCharsets: const <String>['gbk'],
      confidenceThreshold: 0.65,
    );

    expect(result.tags.title, '修复后的标题');
    expect(result.fields['title']?.repaired, isTrue);
    expect(result.fields['title']?.uncertain, isFalse);
  });

  test('keeps baseline when confidence is low', () {
    final engine = DirtyTextRepairEngine(
      detector: const _FakeDetector(
        encoding: 'gbk',
        confidence: 0.40,
        decoded: '修复后的标题',
      ),
    );

    final rawTags = const BasicTags(title: 'ÀÞ¸è');
    final issues = <TextIssue>[
      TextIssue(
        source: TextIssueSource.id3v2Latin1,
        fieldPath: 'id3v2.TIT2[0]',
        frameId: 'TIT2',
        language: null,
        description: null,
        rawBytes: Uint8List.fromList(const <int>[0xc0, 0xde, 0xb8, 0xe8]),
        baselineDecoded: 'ÀÞ¸è',
      ),
    ];

    final result = engine.repair(
      rawTags: rawTags,
      issues: issues,
      preferredCharsets: const <String>['gbk'],
      confidenceThreshold: 0.65,
    );

    expect(result.tags.title, 'ÀÞ¸è');
    expect(result.fields['title']?.repaired, isFalse);
    expect(result.fields['title']?.uncertain, isTrue);
  });
}

final class _ThrowingDetector implements CharsetDetector {
  @override
  CharsetDetection? detect(Uint8List bytes, {List<String>? preferredCharsets}) {
    throw StateError('detector failed');
  }
}

void mainDirtyTextRepairB13() {
  group('B13 dirty text repair guards', () {
    test('detector exception marks field uncertain and keeps raw tag', () {
      final engine = DirtyTextRepairEngine(detector: _ThrowingDetector());
      final result = engine.repair(
        rawTags: const BasicTags(title: 'raw'),
        issues: <TextIssue>[
          TextIssue(
            source: TextIssueSource.id3v1,
            fieldPath: 'id3v1.title',
            frameId: null,
            language: null,
            description: null,
            rawBytes: Uint8List.fromList(<int>[0xff]),
            baselineDecoded: 'baseline',
          ),
        ],
        preferredCharsets: null,
        confidenceThreshold: 0.65,
      );

      expect(result.tags.title, 'raw');
      expect(result.fields['title']?.uncertain, isTrue);
      expect(result.fields['title']?.repaired, isFalse);
    });

    test('confidenceThreshold is validated', () {
      final engine = DirtyTextRepairEngine();
      expect(
        () => engine.repair(
          rawTags: const BasicTags(),
          issues: const <TextIssue>[],
          preferredCharsets: null,
          confidenceThreshold: -0.1,
        ),
        throwsRangeError,
      );
      expect(
        () => engine.repair(
          rawTags: const BasicTags(),
          issues: const <TextIssue>[],
          preferredCharsets: null,
          confidenceThreshold: double.nan,
        ),
        throwsRangeError,
      );
    });
  });
}
