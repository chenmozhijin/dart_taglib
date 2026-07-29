// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

const int _warmupIterations = 128;
const int _batchCount = 8;
const int _iterationsPerBatch = 256;
const int _maximumRssGrowthBytes = 64 * 1024 * 1024;

typedef _MallocTrimNative = Int32 Function(UintPtr);
typedef _MallocTrimDart = int Function(int);

Map<String, int>? _readLinuxSmapsRollup() {
  if (!Platform.isLinux) {
    return null;
  }
  final file = File('/proc/self/smaps_rollup');
  if (!file.existsSync()) {
    return null;
  }
  final values = <String, int>{};
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^([A-Za-z_]+):\s+(\d+)\s+kB$').firstMatch(line);
    if (match == null) {
      continue;
    }
    values[match.group(1)!] = int.parse(match.group(2)!) * 1024;
  }
  return values;
}

int? _trimLinuxAllocator() {
  if (!Platform.isLinux) {
    return null;
  }
  try {
    final mallocTrim = DynamicLibrary.process()
        .lookupFunction<_MallocTrimNative, _MallocTrimDart>('malloc_trim');
    return mallocTrim(0);
  } on ArgumentError {
    return null;
  }
}

Future<VmService> _connectVmService() async {
  final serverUri = (await developer.Service.getInfo()).serverUri;
  if (serverUri == null) {
    throw StateError('The RSS probe requires a VM service connection.');
  }
  final webSocketUri = serverUri.replace(
    scheme: serverUri.scheme == 'https' ? 'wss' : 'ws',
    path: '${serverUri.path}ws',
  );
  return vmServiceConnectUri(webSocketUri.toString());
}

Future<void> _collectGarbage(VmService service) async {
  final vm = await service.getVM();
  final isolate = vm.isolates?.firstWhere(
    (candidate) => candidate.name == 'main',
    orElse: () => throw StateError('Unable to find the RSS probe isolate.'),
  );
  final isolateId = isolate?.id;
  if (isolateId == null) {
    throw StateError('The RSS probe isolate has no service ID.');
  }
  await service.getAllocationProfile(isolateId, gc: true);
}

void _runBatch(TaglibApi api, Uint8List bytes, int iterations) {
  for (var index = 0; index < iterations; index++) {
    final session = api.openSession(bytes, nameHint: 'lossless.wma');
    try {
      // Read two different outputs to cover TagLib object access and FFI output
      // release paths.
      session.readBasicTags();
      session.readAudioProperties();
    } finally {
      // The pressure evidence relies on synchronous close, not on the
      // nondeterministic scheduling of the GC finalizer.
      session.close();
    }
  }
}

Future<void> main() async {
  final fixture = File('test/fixtures/taglib_data/lossless.wma');
  if (!fixture.existsSync()) {
    stderr.writeln('Missing RSS fixture: ${fixture.path}');
    exitCode = 2;
    return;
  }

  final bytes = fixture.readAsBytesSync();
  final api = TaglibApi();
  final vmService = await _connectVmService();

  // Warm up JIT, dynamic-library loading, and allocator growth so one-time
  // startup costs are not mistaken for a leak.
  _runBatch(api, bytes, _warmupIterations);
  await _collectGarbage(vmService);
  final samples = <int>[ProcessInfo.currentRss];
  for (var batch = 0; batch < _batchCount; batch++) {
    _runBatch(api, bytes, _iterationsPerBatch);
    await _collectGarbage(vmService);
    samples.add(ProcessInfo.currentRss);
  }
  await vmService.dispose();

  final totalGrowth = samples.last - samples.first;
  final lateSamples = samples.skip(samples.length ~/ 2).toList();
  final lateMinimum = lateSamples.reduce(
    (left, right) => left < right ? left : right,
  );
  final lateMaximum = lateSamples.reduce(
    (left, right) => left > right ? left : right,
  );
  final lateSpan = lateMaximum - lateMinimum;
  final smapsBeforeTrim = _readLinuxSmapsRollup();
  final rssBeforeTrim = ProcessInfo.currentRss;
  final trimResult = _trimLinuxAllocator();
  final rssAfterTrim = ProcessInfo.currentRss;
  final smapsAfterTrim = _readLinuxSmapsRollup();
  final evidence = <String, Object>{
    'fixtureBytes': bytes.length,
    'warmupIterations': _warmupIterations,
    'measuredIterations': _batchCount * _iterationsPerBatch,
    'rssSamplesBytes': samples,
    'totalGrowthBytes': totalGrowth,
    'lateSpanBytes': lateSpan,
    'limitBytes': _maximumRssGrowthBytes,
    'forcedGcBeforeSamples': true,
    'allocatorTrimResult': ?trimResult,
    'rssBeforeAllocatorTrimBytes': rssBeforeTrim,
    'rssAfterAllocatorTrimBytes': rssAfterTrim,
    'smapsBeforeAllocatorTrimBytes': ?smapsBeforeTrim,
    'smapsAfterAllocatorTrimBytes': ?smapsAfterTrim,
  };
  stdout.writeln('DART_TAGLIB_RSS ${jsonEncode(evidence)}');

  if (totalGrowth > _maximumRssGrowthBytes ||
      lateSpan > _maximumRssGrowthBytes) {
    exitCode = 1;
  }
}
