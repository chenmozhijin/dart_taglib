// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

import '../fixture_matrix.dart';

typedef FixtureBytesLoader = Future<Uint8List> Function(FixtureCase fixture);

final class FixtureMatrixRunner {
  FixtureMatrixRunner({
    required TaglibApi api,
    required FixtureBytesLoader loadBytes,
  }) : _api = api,
       _loadBytes = loadBytes;

  final TaglibApi _api;
  final FixtureBytesLoader _loadBytes;
  static const SessionCapabilities _mpegCapabilities = SessionCapabilities(
    plainLyricsWritable: true,
    syncedLyricsWritable: true,
    mp3Id3SaveSupported: true,
    uslt: true,
    lyrics: false,
    mp4Lyr: false,
    wmLyrics: false,
    hintBased: false,
  );
  static const SessionCapabilities _mp4Capabilities = SessionCapabilities(
    plainLyricsWritable: true,
    syncedLyricsWritable: false,
    mp3Id3SaveSupported: false,
    uslt: false,
    lyrics: false,
    mp4Lyr: true,
    wmLyrics: false,
    hintBased: false,
  );
  static const SessionCapabilities _asfCapabilities = SessionCapabilities(
    plainLyricsWritable: true,
    syncedLyricsWritable: false,
    mp3Id3SaveSupported: false,
    uslt: false,
    lyrics: false,
    mp4Lyr: false,
    wmLyrics: true,
    hintBased: false,
  );
  static const SessionCapabilities _genericLyricsCapabilities =
      SessionCapabilities(
        plainLyricsWritable: true,
        syncedLyricsWritable: false,
        mp3Id3SaveSupported: false,
        uslt: false,
        lyrics: true,
        mp4Lyr: false,
        wmLyrics: false,
        hintBased: false,
      );
  static const SessionCapabilities _runtimeUnknownCapabilities =
      SessionCapabilities(
        plainLyricsWritable: false,
        syncedLyricsWritable: false,
        mp3Id3SaveSupported: false,
        uslt: false,
        lyrics: false,
        mp4Lyr: false,
        wmLyrics: false,
        hintBased: false,
      );

  Future<void> runFixture(FixtureCase fixture) async {
    final bytes = fixture.useEmptyBytes
        ? Uint8List(0)
        : fixture.buildDefaultBytes(await _loadBytes(fixture));

    if (fixture.profile == FixtureProfile.openFail) {
      _expectStatus(
        () => _api.openSession(bytes, nameHint: fixture.nameHint),
        fixture.expectedOpenStatus,
      );
      return;
    }

    TaglibSession session;
    try {
      session = _api.openSession(bytes, nameHint: fixture.nameHint);
    } on TaglibException catch (error) {
      // Some samples are matrix-covered but intentionally unsupported in the
      // current build profile (e.g. optional TagLib format toggles).
      if (fixture.expectedOpenStatus != statusOk &&
          error.statusCode == fixture.expectedOpenStatus) {
        return;
      }
      rethrow;
    }

    try {
      _expectCapabilities(
        session.probeCapabilities(),
        _expectedCapabilitiesForFixture(fixture),
      );

      switch (fixture.profile) {
        case FixtureProfile.mp3Full:
          _runMp3Full(fixture, session);
        case FixtureProfile.genericRw:
          _runGenericRw(fixture, session);
        case FixtureProfile.readOnly:
          _runReadOnly(session);
        case FixtureProfile.openFail:
          fail('unreachable fixture profile: ${fixture.profile}');
      }
    } finally {
      session.close();
    }
  }

  void _runMp3Full(FixtureCase fixture, TaglibSession session) {
    final marker = _marker(fixture.id);
    final tags = BasicTags(
      title: 'matrix-title-$marker',
      artist: 'matrix-artist-$marker',
      album: 'matrix-album-$marker',
      comment: 'matrix-comment-$marker',
      genre: 'matrix-genre-$marker',
      year: 2026,
      track: 7,
    );
    final lyrics = 'matrix-lyrics-$marker';
    final syltTrack = SyncedLyricsTrack(
      language: 'eng',
      description: 'SYNC_$marker',
      type: SyncedLyricsType.lyrics,
      timestampFormat: SyncedLyricsTimestampFormat.milliseconds,
      entries: <SyncedLyricsEntry>[
        SyncedLyricsEntry(time: 0, text: 'line-a-$marker'),
        SyncedLyricsEntry(time: 1350, text: 'line-b-$marker'),
      ],
    );
    final propertyMap = PropertyMap(
      items: <PropertyItem>[
        PropertyItem(key: 'TITLE', values: <String>[tags.title!]),
        PropertyItem(key: 'ARTIST', values: <String>[tags.artist!]),
        PropertyItem(key: 'ALBUM', values: <String>[tags.album!]),
      ],
    );
    final picture = PictureItem(
      mimeType: 'image/png',
      description: 'cover-$marker',
      pictureType: 'Front Cover',
      data: Uint8List.fromList(<int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        ...marker.codeUnits.take(8),
      ]),
    );

    expect(() => session.readBasicTags(), returnsNormally);
    expect(
      session.readAudioProperties(),
      anyOf(isNull, isA<AudioProperties>()),
    );
    expect(() => session.readPropertyMap(), returnsNormally);
    expect(() => session.scanTextIssues(), returnsNormally);

    session.writeBasicTags(tags, id3v2Version: Id3v2Version.v24);
    session.writePropertyMap(propertyMap);
    session.writePictures(<PictureItem>[picture], clearExisting: true);
    session.writeLyrics(
      lyrics,
      language: 'eng',
      description: 'LYRICS',
      id3v2Version: Id3v2Version.v24,
    );
    session.writeSyncedLyrics(
      <SyncedLyricsTrack>[syltTrack],
      mergeMode: SyltMergeMode.replaceByKey,
      id3v2Version: Id3v2Version.v24,
    );

    _assertSaveStatus(session, fixture.expectedSaveMp3Status);

    final exported = session.exportBytes();
    expect(exported, isNotEmpty);

    final verify = _api.openSession(exported, nameHint: fixture.nameHint);
    try {
      final roundtripTags = verify.readBasicTags();
      expect(roundtripTags.title, tags.title);
      expect(roundtripTags.artist, tags.artist);
      expect(roundtripTags.album, tags.album);
      expect(roundtripTags.comment, anyOf(isNull, tags.comment));
      expect(roundtripTags.genre, anyOf(isNull, tags.genre));
      expect(roundtripTags.year, anyOf(0, tags.year));
      expect(roundtripTags.track, anyOf(0, tags.track));

      expect(verify.readLyrics(), lyrics);

      final tracks = verify.readSyncedLyrics();
      final matched = tracks.firstWhere(
        (track) =>
            track.description == syltTrack.description &&
            track.language == syltTrack.language &&
            track.type == syltTrack.type,
      );
      expect(
        matched.entries.map((entry) => entry.time),
        orderedEquals(syltTrack.entries.map((entry) => entry.time)),
      );
      expect(
        matched.entries.map((entry) => entry.text),
        orderedEquals(syltTrack.entries.map((entry) => entry.text)),
      );

      final pictures = verify.readPictures();
      expect(pictures, isNotEmpty);
      expect(pictures.first.data, isNotEmpty);
      expect(pictures.first.mimeType, 'image/png');

      expect(() => verify.readPropertyMap(), returnsNormally);
      expect(() => verify.scanTextIssues(), returnsNormally);
    } finally {
      verify.close();
    }
  }

  void _runGenericRw(FixtureCase fixture, TaglibSession session) {
    final marker = _marker(fixture.id);
    final tags = BasicTags(
      title: 'generic-title-$marker',
      artist: 'generic-artist-$marker',
      album: 'generic-album-$marker',
      comment: 'generic-comment-$marker',
      genre: 'generic-genre-$marker',
      year: 2026,
      track: 9,
    );
    final lyrics = 'generic-lyrics-$marker';
    final map = PropertyMap(
      items: <PropertyItem>[
        PropertyItem(key: 'TITLE', values: <String>[tags.title!]),
        PropertyItem(key: 'ARTIST', values: <String>[tags.artist!]),
      ],
    );

    expect(() => session.readBasicTags(), returnsNormally);
    expect(
      session.readAudioProperties(),
      anyOf(isNull, isA<AudioProperties>()),
    );
    expect(() => session.readPropertyMap(), returnsNormally);
    expect(() => session.scanTextIssues(), returnsNormally);

    session.writeBasicTags(tags, id3v2Version: Id3v2Version.v24);
    session.writePropertyMap(map);
    session.writeLyrics(
      lyrics,
      language: 'eng',
      description: 'LYRICS',
      id3v2Version: Id3v2Version.v24,
    );
    _assertSaveStatus(session, fixture.expectedSaveMp3Status);

    final exported = session.exportBytes();
    expect(exported, isNotEmpty);

    TaglibSession verify;
    try {
      verify = _api.openSession(exported, nameHint: fixture.nameHint);
    } on TaglibException catch (error) {
      if (fixture.expectedOpenStatus != statusOk &&
          error.statusCode == fixture.expectedOpenStatus) {
        return;
      }
      rethrow;
    }
    try {
      expect(() => verify.readBasicTags(), returnsNormally);

      final readBackLyrics = verify.readLyrics();
      expect(readBackLyrics, anyOf(isNull, lyrics));

      expect(() => verify.readPropertyMap(), returnsNormally);
      expect(() => verify.scanTextIssues(), returnsNormally);
    } finally {
      verify.close();
    }
  }

  void _runReadOnly(TaglibSession session) {
    expect(() => session.readBasicTags(), returnsNormally);
    expect(
      session.readAudioProperties(),
      anyOf(isNull, isA<AudioProperties>()),
    );
    expect(() => session.readPropertyMap(), returnsNormally);
    expect(() => session.scanTextIssues(), returnsNormally);

    final exported = session.exportBytes();
    expect(exported, isNotEmpty);
  }

  void _assertSaveStatus(TaglibSession session, int expectedStatus) {
    if (expectedStatus == statusOk) {
      session.saveMp3WithId3v2Version(version: Id3v2Version.v24);
      return;
    }

    _expectStatus(
      () => session.saveMp3WithId3v2Version(version: Id3v2Version.v24),
      expectedStatus,
    );
  }

  static void _expectStatus(void Function() run, int expectedStatus) {
    expect(
      run,
      throwsA(
        isA<TaglibException>().having(
          (error) => error.statusCode,
          'statusCode',
          expectedStatus,
        ),
      ),
    );
  }

  static String _marker(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_').toUpperCase();
  }

  static SessionCapabilities _expectedCapabilitiesForFixture(
    FixtureCase fixture,
  ) {
    if (fixture.profile == FixtureProfile.mp3Full) {
      return _mpegCapabilities;
    }
    if (fixture.profile == FixtureProfile.readOnly) {
      return _runtimeUnknownCapabilities;
    }
    if (fixture.profile != FixtureProfile.genericRw) {
      return _runtimeUnknownCapabilities;
    }

    final String lowerName = fixture.nameHint.toLowerCase();
    if (lowerName.endsWith('.mp3') || lowerName.endsWith('.aac')) {
      return _mpegCapabilities;
    }
    if (lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.m4b') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.3g2') ||
        lowerName.endsWith('.3gp')) {
      return _mp4Capabilities;
    }
    if (lowerName.endsWith('.wma') || lowerName.endsWith('.asf')) {
      return _asfCapabilities;
    }
    return _genericLyricsCapabilities;
  }

  static void _expectCapabilities(
    SessionCapabilities actual,
    SessionCapabilities expected,
  ) {
    expect(actual.plainLyricsWritable, expected.plainLyricsWritable);
    expect(actual.syncedLyricsWritable, expected.syncedLyricsWritable);
    expect(actual.mp3Id3SaveSupported, expected.mp3Id3SaveSupported);
    expect(actual.uslt, expected.uslt);
    expect(actual.lyrics, expected.lyrics);
    expect(actual.mp4Lyr, expected.mp4Lyr);
    expect(actual.wmLyrics, expected.wmLyrics);
    expect(actual.hintBased, expected.hintBased);
  }
}
