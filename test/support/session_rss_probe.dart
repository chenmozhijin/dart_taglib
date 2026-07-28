// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';

const int _warmupIterations = 128;
const int _batchCount = 8;
const int _iterationsPerBatch = 256;
const int _maximumRssGrowthBytes = 64 * 1024 * 1024;

void _runBatch(TaglibApi api, Uint8List bytes, int iterations) {
  for (var index = 0; index < iterations; index++) {
    final session = api.openSession(bytes, nameHint: 'lossless.wma');
    try {
      // 读取两个不同输出，覆盖 TagLib 对象访问和 FFI 输出结构的释放路径。
      session.readBasicTags();
      session.readAudioProperties();
    } finally {
      // 压力证据只依赖同步 close，不依赖无法确定调度时机的 GC finalizer。
      session.close();
    }
  }
}

void main() {
  final fixture = File('test/fixtures/taglib_data/lossless.wma');
  if (!fixture.existsSync()) {
    stderr.writeln('Missing RSS fixture: ${fixture.path}');
    exitCode = 2;
    return;
  }

  final bytes = fixture.readAsBytesSync();
  final api = TaglibApi();

  // 先触发 JIT、动态库加载和分配器首次扩容，避免把一次性启动成本误判为泄漏。
  _runBatch(api, bytes, _warmupIterations);
  final samples = <int>[ProcessInfo.currentRss];
  for (var batch = 0; batch < _batchCount; batch++) {
    _runBatch(api, bytes, _iterationsPerBatch);
    samples.add(ProcessInfo.currentRss);
  }

  final totalGrowth = samples.last - samples.first;
  final lateSamples = samples.skip(samples.length ~/ 2).toList();
  final lateMinimum = lateSamples.reduce(
    (left, right) => left < right ? left : right,
  );
  final lateMaximum = lateSamples.reduce(
    (left, right) => left > right ? left : right,
  );
  final lateSpan = lateMaximum - lateMinimum;
  final evidence = <String, Object>{
    'fixtureBytes': bytes.length,
    'warmupIterations': _warmupIterations,
    'measuredIterations': _batchCount * _iterationsPerBatch,
    'rssSamplesBytes': samples,
    'totalGrowthBytes': totalGrowth,
    'lateSpanBytes': lateSpan,
    'limitBytes': _maximumRssGrowthBytes,
  };
  stdout.writeln('DART_TAGLIB_RSS ${jsonEncode(evidence)}');

  if (totalGrowth > _maximumRssGrowthBytes ||
      lateSpan > _maximumRssGrowthBytes) {
    exitCode = 1;
  }
}
