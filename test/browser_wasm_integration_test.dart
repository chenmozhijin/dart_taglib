// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

import 'support/browser_wasm_loader.dart';

const String _sampleAsset = 'fixtures/sample.mp3';
// Generate web_runtime assets from repo root with:
// ./tool/build_wasm.ps1
// ./tool/prepare_browser_test_assets.ps1

Future<Uint8List> _loadSampleBytes() => fetchBrowserBytes(_sampleAsset);

Future<void> _initializeBridge() async {
  await Future.wait(<Future<void>>[
    initializeTaglibWasmBridge(),
    initializeTaglibWasmBridge(),
  ]);
}

void main() {
  late TaglibApi api;
  late Uint8List sampleBytes;

  setUpAll(() async {
    await _initializeBridge();
    sampleBytes = await _loadSampleBytes();
    api = TaglibApi();
  });

  test('session full roundtrip via wasm bytes API in browser', () {
    expect(hasTaglibWasmBridge(), isTrue);
    const expectedTags = BasicTags(
      title: 'Browser Session Title',
      artist: 'Browser Session Artist',
      album: 'Browser Session Album',
      comment: 'Browser Session Comment',
      genre: 'Browser Session Genre',
      year: 2026,
      track: 6,
    );
    const expectedLyrics = 'browser integration lyrics';
    final expectedTrack = SyncedLyricsTrack(
      language: 'eng',
      description: 'BROWSER_SYNC',
      type: SyncedLyricsType.lyrics,
      timestampFormat: SyncedLyricsTimestampFormat.milliseconds,
      entries: <SyncedLyricsEntry>[
        SyncedLyricsEntry(time: 0, text: 'browser line 1'),
        SyncedLyricsEntry(time: 1400, text: 'browser line 2'),
      ],
    );

    final session = api.openSession(sampleBytes, nameHint: 'sample.mp3');
    try {
      final capabilities = session.probeCapabilities();
      expect(capabilities.plainLyricsWritable, isTrue);
      expect(capabilities.syncedLyricsWritable, isTrue);
      expect(capabilities.mp3Id3SaveSupported, isTrue);
      expect(capabilities.uslt, isTrue);
      expect(capabilities.hintBased, isFalse);

      session.writeBasicTags(expectedTags, id3v2Version: Id3v2Version.v24);
      session.writeLyrics(
        expectedLyrics,
        language: 'eng',
        description: 'LYRICS',
        id3v2Version: Id3v2Version.v24,
      );
      session.writeSyncedLyrics(
        <SyncedLyricsTrack>[expectedTrack],
        mergeMode: SyltMergeMode.replaceByKey,
        id3v2Version: Id3v2Version.v24,
      );

      final basic = session.readBasicTags();
      expect(basic.title, expectedTags.title);
      expect(basic.artist, expectedTags.artist);
      expect(basic.album, expectedTags.album);
      expect(basic.comment, expectedTags.comment);
      expect(basic.genre, expectedTags.genre);
      expect(basic.year, expectedTags.year);
      expect(basic.track, expectedTags.track);

      final readLyrics = session.readLyrics(
        language: 'eng',
        description: 'LYRICS',
      );
      expect(readLyrics, expectedLyrics);

      final tracks = session.readSyncedLyrics();
      final track = tracks.firstWhere((item) {
        return item.language == expectedTrack.language &&
            item.description == expectedTrack.description &&
            item.type == expectedTrack.type;
      });
      expect(
        track.entries.map((entry) => entry.time).toList(),
        orderedEquals(expectedTrack.entries.map((entry) => entry.time)),
      );
      expect(
        track.entries.map((entry) => entry.text).toList(),
        orderedEquals(expectedTrack.entries.map((entry) => entry.text)),
      );

      final exported = session.exportBytes();
      expect(exported, isNotEmpty);

      final verifySession = api.openSession(exported, nameHint: 'sample.mp3');
      try {
        final verifyBasic = verifySession.readBasicTags();
        expect(verifyBasic.title, expectedTags.title);
        expect(verifyBasic.artist, expectedTags.artist);
        expect(verifyBasic.album, expectedTags.album);
        expect(verifyBasic.comment, expectedTags.comment);
        expect(verifyBasic.genre, expectedTags.genre);
        expect(verifyBasic.year, expectedTags.year);
        expect(verifyBasic.track, expectedTags.track);

        final verifyLyrics = verifySession.readLyrics(
          language: 'eng',
          description: 'LYRICS',
        );
        expect(verifyLyrics, expectedLyrics);

        final verifyTracks = verifySession.readSyncedLyrics();
        final verifyTrack = verifyTracks.firstWhere((item) {
          return item.language == expectedTrack.language &&
              item.description == expectedTrack.description &&
              item.type == expectedTrack.type;
        });
        expect(
          verifyTrack.entries.map((entry) => entry.time).toList(),
          orderedEquals(expectedTrack.entries.map((entry) => entry.time)),
        );
        expect(
          verifyTrack.entries.map((entry) => entry.text).toList(),
          orderedEquals(expectedTrack.entries.map((entry) => entry.text)),
        );
      } finally {
        verifySession.close();
      }
    } finally {
      session.close();
    }
  });
}
