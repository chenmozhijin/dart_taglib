// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

const int _statusInvalidArgument = 1;
const int _statusUnsupportedFormat = 3;

final class _NamedFixture {
  const _NamedFixture(this.path, this.nameHint);

  final String path;
  final String nameHint;
}

Uint8List _readFixtureBytes(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Fixture not found: $path');
  }
  return file.readAsBytesSync();
}

({Directory directory, File file}) _createTempAudioFile(
  Uint8List bytes, {
  String fileName = 'sample.mp3',
}) {
  final directory = Directory.systemTemp.createTempSync('dart_taglib_test_');
  final file = File('${directory.path}/$fileName');
  file.writeAsBytesSync(bytes, flush: true);
  return (directory: directory, file: file);
}

typedef _PosixOpenNative = ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Int32);
typedef _PosixOpen = int Function(ffi.Pointer<Utf8>, int);
typedef _PosixCloseNative = ffi.Int32 Function(ffi.Int32);
typedef _PosixClose = int Function(int);

ffi.DynamicLibrary _openPosixLibc() {
  if (Platform.isLinux || Platform.isAndroid) {
    return ffi.DynamicLibrary.open('libc.so.6');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return ffi.DynamicLibrary.open('/usr/lib/libSystem.B.dylib');
  }
  throw UnsupportedError('Unsupported platform for fd test.');
}

int _openReadWriteFileDescriptor(String path) {
  final libc = _openPosixLibc();
  final pathPtr = path.toNativeUtf8();
  try {
    final open = libc.lookupFunction<_PosixOpenNative, _PosixOpen>('open');
    const int oReadWrite = 2;
    final fd = open(pathPtr, oReadWrite);
    if (fd < 0) {
      throw StateError('Failed to open file descriptor for: $path');
    }
    return fd;
  } finally {
    calloc.free(pathPtr);
  }
}

void _closeFileDescriptor(int fileDescriptor) {
  final libc = _openPosixLibc();
  final close = libc.lookupFunction<_PosixCloseNative, _PosixClose>('close');
  close(fileDescriptor);
}

BasicTags _readBasicTags(TaglibApi api, Uint8List bytes) {
  final session = api.openSession(bytes, nameHint: 'sample.mp3');
  try {
    return session.readBasicTags();
  } finally {
    session.close();
  }
}

List<TextIssue> _scanTextIssues(TaglibApi api, Uint8List bytes) {
  final session = api.openSession(bytes, nameHint: 'sample.mp3');
  try {
    return session.scanTextIssues();
  } finally {
    session.close();
  }
}

Uint8List _manualWrite(
  TaglibApi api,
  Uint8List input,
  void Function(TaglibSession session) mutate,
) {
  final session = api.openSession(input, nameHint: 'sample.mp3');
  try {
    mutate(session);
    return session.exportBytes();
  } finally {
    session.close();
  }
}

Map<String, List<String>> _propertyMapIndex(PropertyMap map) {
  return <String, List<String>>{
    for (final item in map.items) item.key.toUpperCase(): item.values,
  };
}

String _issueSignature(TextIssue issue) {
  return [
    issue.source.nativeValue,
    issue.fieldPath ?? '',
    issue.frameId ?? '',
    issue.language ?? '',
    issue.description ?? '',
    issue.baselineDecoded ?? '',
    issue.rawBytes.length,
  ].join('|');
}

SyncedLyricsTrack _findTrack(
  List<SyncedLyricsTrack> tracks, {
  required String language,
  required String description,
  required SyncedLyricsType type,
}) {
  return tracks.firstWhere((track) {
    return track.language == language &&
        track.description == description &&
        track.type == type;
  });
}

void _expectBasicTagsEqual(BasicTags actual, BasicTags expected) {
  expect(actual.title, expected.title);
  expect(actual.artist, expected.artist);
  expect(actual.album, expected.album);
  expect(actual.comment, expected.comment);
  expect(actual.genre, expected.genre);
  expect(actual.lyrics, expected.lyrics);
  expect(actual.year, expected.year);
  expect(actual.track, expected.track);
}

void _expectLyricsRoundtripOnFixture(
  TaglibApi api, {
  required String fixturePath,
  required String nameHint,
  required String lyrics,
}) {
  final inputBytes = _readFixtureBytes(fixturePath);
  final writeSession = api.openSession(inputBytes, nameHint: nameHint);
  late Uint8List exported;
  try {
    writeSession.writeLyrics(
      lyrics,
      language: 'eng',
      description: 'LYRICS',
      id3v2Version: Id3v2Version.v24,
    );
    exported = writeSession.exportBytes();
  } finally {
    writeSession.close();
  }

  final verifySession = api.openSession(exported, nameHint: nameHint);
  try {
    expect(
      verifySession.readLyrics(language: 'eng', description: 'LYRICS'),
      lyrics,
    );
  } finally {
    verifySession.close();
  }
}

void main() {
  late TaglibApi api;
  late Uint8List sampleMp3Bytes;
  late _NamedFixture nonMp3Fixture;

  setUpAll(() {
    // The integration test must cover the published package's default Native
    // Assets loading path.
    api = TaglibApi();
    sampleMp3Bytes = _readFixtureBytes('test/fixtures/sample.mp3');

    const candidates = <_NamedFixture>[
      _NamedFixture('third_party/taglib/tests/data/empty.wav', 'empty.wav'),
      _NamedFixture(
        'third_party/taglib/tests/data/no-tags.flac',
        'no-tags.flac',
      ),
      _NamedFixture('third_party/taglib/tests/data/no-tags.m4a', 'no-tags.m4a'),
    ];

    for (final candidate in candidates) {
      if (File(candidate.path).existsSync()) {
        nonMp3Fixture = candidate;
        return;
      }
    }

    throw StateError(
      'No non-MP3 fixture found in third_party/taglib/tests/data.',
    );
  });

  group('session full roundtrip (vm)', () {
    test('writePicturesFromFiles writes cover without Dart byte payload', () {
      final temp = _createTempAudioFile(sampleMp3Bytes);
      final picture = File('${temp.directory.path}/cover.bin');
      final expected = Uint8List.fromList(const <int>[0, 1, 2, 3, 4, 5, 6]);
      picture.writeAsBytesSync(expected, flush: true);
      addTearDown(() => temp.directory.deleteSync(recursive: true));

      final session = api.openSessionFromPath(temp.file.path);
      try {
        session.writePicturesFromFiles(<PictureFileItem>[
          PictureFileItem(
            path: picture.path,
            mimeType: 'image/png',
            description: 'path-cover',
            pictureType: 'Front Cover',
          ),
        ]);
      } finally {
        session.close();
      }

      final verify = api.openSessionFromPath(temp.file.path);
      try {
        final PictureItem written = verify.readPictures().single;
        expect(written.mimeType, 'image/png');
        expect(written.description, 'path-cover');
        expect(written.data, expected);
      } finally {
        verify.close();
      }
    });

    test('supports full write chain and reopen assertions', () {
      const expectedTags = BasicTags(
        title: 'Session Title',
        artist: 'Session Artist',
        album: 'Session Album',
        comment: 'Session Comment',
        genre: 'Session Genre',
        year: 2026,
        track: 8,
      );
      const expectedLyrics = 'Session lyrics line 1\nSession lyrics line 2';
      final expectedTrack = SyncedLyricsTrack(
        language: 'eng',
        description: 'SYNC_MAIN',
        type: SyncedLyricsType.lyrics,
        timestampFormat: SyncedLyricsTimestampFormat.milliseconds,
        entries: <SyncedLyricsEntry>[
          SyncedLyricsEntry(time: 0, text: 'session line 1'),
          SyncedLyricsEntry(time: 1120, text: 'session line 2'),
          SyncedLyricsEntry(time: 2450, text: 'session line 3'),
        ],
      );
      final expectedPropertyMap = PropertyMap(
        items: <PropertyItem>[
          PropertyItem(key: 'TITLE', values: <String>['Session Title']),
          PropertyItem(key: 'ARTIST', values: <String>['Session Artist']),
          PropertyItem(key: 'ALBUM', values: <String>['Session Album']),
          PropertyItem(key: 'COMMENT', values: <String>['Session Comment']),
          PropertyItem(key: 'GENRE', values: <String>['Session Genre']),
          PropertyItem(key: 'TRACKNUMBER', values: <String>['8']),
          PropertyItem(key: 'DATE', values: <String>['2026']),
          PropertyItem(key: 'LYRICS:LYRICS', values: <String>[expectedLyrics]),
        ],
      );
      final expectedPictureBytes = Uint8List.fromList(const <int>[
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);

      final session = api.openSession(sampleMp3Bytes, nameHint: 'sample.mp3');
      late Uint8List exported;
      try {
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
        session.writePropertyMap(expectedPropertyMap);
        session.writePictures(<PictureItem>[
          PictureItem(
            mimeType: 'image/png',
            description: 'front-cover',
            pictureType: 'Front Cover',
            data: expectedPictureBytes,
          ),
        ], clearExisting: true);
        session.saveMp3WithId3v2Version(version: Id3v2Version.v23);

        exported = session.exportBytes();
        expect(exported, isNotEmpty);
      } finally {
        session.close();
      }

      final verifySession = api.openSession(exported, nameHint: 'sample.mp3');
      try {
        final basicTags = verifySession.readBasicTags();
        _expectBasicTagsEqual(
          basicTags,
          expectedTags.copyWith(lyrics: expectedLyrics),
        );

        final lyrics = verifySession.readLyrics();
        expect(lyrics, expectedLyrics);

        final tracks = verifySession.readSyncedLyrics();
        final foundTrack = _findTrack(
          tracks,
          language: expectedTrack.language,
          description: expectedTrack.description,
          type: expectedTrack.type,
        );
        expect(foundTrack.timestampFormat, expectedTrack.timestampFormat);
        expect(
          foundTrack.entries.map((item) => item.time).toList(),
          orderedEquals(expectedTrack.entries.map((item) => item.time)),
        );
        expect(
          foundTrack.entries.map((item) => item.text).toList(),
          orderedEquals(expectedTrack.entries.map((item) => item.text)),
        );

        final properties = verifySession.readPropertyMap();
        final propertyIndex = _propertyMapIndex(properties);
        for (final expected in expectedPropertyMap.items.where(
          (item) => item.key != 'LYRICS:LYRICS',
        )) {
          expect(
            propertyIndex[expected.key],
            orderedEquals(expected.values),
            reason: 'Missing property map key: ${expected.key}',
          );
        }

        final pictures = verifySession.readPictures();
        expect(pictures, hasLength(1));
        expect(pictures.single.mimeType, 'image/png');
        expect(pictures.single.description, 'front-cover');
        expect(pictures.single.data, orderedEquals(expectedPictureBytes));

        final audio = verifySession.readAudioProperties();
        expect(audio, isNotNull);
        expect(audio!.lengthSeconds, greaterThanOrEqualTo(0));

        final textIssues = verifySession.scanTextIssues();
        expect(textIssues, isA<List<TextIssue>>());
      } finally {
        verifySession.close();
      }
    });

    test(
      'repeated writeSyncedLyrics with replaceByKey keeps single track key',
      () {
        const trackKey = (
          language: 'eng',
          description: 'SYNC_REPLACE_KEY',
          type: SyncedLyricsType.lyrics,
        );
        final firstTrack = SyncedLyricsTrack(
          language: trackKey.language,
          description: trackKey.description,
          type: trackKey.type,
          timestampFormat: SyncedLyricsTimestampFormat.milliseconds,
          entries: <SyncedLyricsEntry>[
            SyncedLyricsEntry(time: 0, text: 'first-a'),
            SyncedLyricsEntry(time: 500, text: 'first-b'),
          ],
        );
        final secondTrack = SyncedLyricsTrack(
          language: trackKey.language,
          description: trackKey.description,
          type: trackKey.type,
          timestampFormat: SyncedLyricsTimestampFormat.milliseconds,
          entries: <SyncedLyricsEntry>[
            SyncedLyricsEntry(time: 0, text: 'second-a'),
            SyncedLyricsEntry(time: 900, text: 'second-b'),
          ],
        );

        final session = api.openSession(sampleMp3Bytes, nameHint: 'sample.mp3');
        late Uint8List exported;
        try {
          session.writeSyncedLyrics(
            <SyncedLyricsTrack>[firstTrack],
            mergeMode: SyltMergeMode.replaceByKey,
            id3v2Version: Id3v2Version.v24,
          );
          session.writeSyncedLyrics(
            <SyncedLyricsTrack>[secondTrack],
            mergeMode: SyltMergeMode.replaceByKey,
            id3v2Version: Id3v2Version.v24,
          );
          exported = session.exportBytes();
        } finally {
          session.close();
        }

        final verify = api.openSession(exported, nameHint: 'sample.mp3');
        try {
          final tracks = verify.readSyncedLyrics();
          final matched = tracks
              .where(
                (item) =>
                    item.language == trackKey.language &&
                    item.description == trackKey.description &&
                    item.type == trackKey.type,
              )
              .toList(growable: false);
          expect(matched, hasLength(1));
          expect(
            matched.single.entries.map((item) => item.text).toList(),
            orderedEquals(secondTrack.entries.map((item) => item.text)),
          );
        } finally {
          verify.close();
        }
      },
    );

    test('writing lyrics repeatedly keeps non-lyrics metadata intact', () {
      final session = api.openSession(sampleMp3Bytes, nameHint: 'sample.mp3');
      late Uint8List exported;
      final pictureBytes = Uint8List.fromList(const <int>[
        137,
        80,
        78,
        71,
        1,
        2,
        3,
        4,
        5,
      ]);
      try {
        session.writeBasicTags(
          const BasicTags(
            title: 'Meta Title',
            artist: 'Meta Artist',
            album: 'Meta Album',
            year: 2026,
            track: 5,
          ),
          id3v2Version: Id3v2Version.v24,
        );
        session.writePictures(<PictureItem>[
          PictureItem(
            mimeType: 'image/png',
            description: 'meta-cover',
            pictureType: 'Front Cover',
            data: pictureBytes,
          ),
        ], clearExisting: true);
        session.writeLyrics(
          'lyrics-v1',
          language: 'eng',
          description: 'LYRICS',
          id3v2Version: Id3v2Version.v24,
        );
        session.writeLyrics(
          'lyrics-v2',
          language: 'eng',
          description: 'LYRICS',
          id3v2Version: Id3v2Version.v24,
        );
        exported = session.exportBytes();
      } finally {
        session.close();
      }

      final verify = api.openSession(exported, nameHint: 'sample.mp3');
      try {
        final tags = verify.readBasicTags();
        expect(tags.title, 'Meta Title');
        expect(tags.artist, 'Meta Artist');
        expect(tags.album, 'Meta Album');
        expect(
          verify.readLyrics(language: 'eng', description: 'LYRICS'),
          'lyrics-v2',
        );
        final pictures = verify.readPictures();
        expect(pictures, isNotEmpty);
        expect(pictures.first.data, orderedEquals(pictureBytes));
      } finally {
        verify.close();
      }
    });

    test('plain lyrics roundtrip works on aac/flac/m4a/wma fixtures', () {
      _expectLyricsRoundtripOnFixture(
        api,
        fixturePath: 'test/fixtures/taglib_data/empty1s.aac',
        nameHint: 'empty1s.aac',
        lyrics: 'aac-lyrics',
      );
      _expectLyricsRoundtripOnFixture(
        api,
        fixturePath: 'test/fixtures/taglib_data/no-tags.flac',
        nameHint: 'no-tags.flac',
        lyrics: 'flac-lyrics',
      );
      _expectLyricsRoundtripOnFixture(
        api,
        fixturePath: 'test/fixtures/taglib_data/no-tags.m4a',
        nameHint: 'no-tags.m4a',
        lyrics: 'm4a-lyrics',
      );
      _expectLyricsRoundtripOnFixture(
        api,
        fixturePath: 'test/fixtures/taglib_data/silence-1.wma',
        nameHint: 'silence-1.wma',
        lyrics: 'wma-lyrics',
      );
    });
  });

  group('session lifecycle and status semantics (vm)', () {
    test(
      'close is idempotent and all operations fail with StateError after close',
      () {
        final session = api.openSession(sampleMp3Bytes, nameHint: 'sample.mp3');
        session.close();
        session.close();

        final operations = <String, void Function()>{
          'readBasicTags': () => session.readBasicTags(),
          'writeBasicTags': () =>
              session.writeBasicTags(const BasicTags(title: 'x')),
          'readAudioProperties': () => session.readAudioProperties(),
          'readPropertyMap': () => session.readPropertyMap(),
          'writePropertyMap': () =>
              session.writePropertyMap(PropertyMap(items: <PropertyItem>[])),
          'readPictures': () => session.readPictures(),
          'writePictures': () => session.writePictures(<PictureItem>[
            PictureItem(data: Uint8List.fromList(const <int>[1, 2, 3])),
          ]),
          'readLyrics': () => session.readLyrics(),
          'writeLyrics': () => session.writeLyrics('closed'),
          'clearLyrics': () => session.clearLyrics(),
          'saveMp3WithId3v2Version': () => session.saveMp3WithId3v2Version(),
          'readSyncedLyrics': () => session.readSyncedLyrics(),
          'writeSyncedLyrics': () =>
              session.writeSyncedLyrics(<SyncedLyricsTrack>[
                SyncedLyricsTrack(
                  language: 'eng',
                  description: 'closed',
                  entries: <SyncedLyricsEntry>[
                    SyncedLyricsEntry(time: 0, text: 'x'),
                  ],
                ),
              ]),
          'clearSyncedLyrics': () => session.clearSyncedLyrics(),
          'scanTextIssues': () => session.scanTextIssues(),
          'exportBytes': () => session.exportBytes(),
        };

        for (final operation in operations.entries) {
          expect(
            operation.value,
            throwsA(isA<StateError>()),
            reason: 'Expected StateError for ${operation.key}',
          );
        }
      },
    );

    test('openSession(emptyBytes) returns INVALID_ARGUMENT', () {
      expect(
        () => api.openSession(Uint8List(0), nameHint: 'empty.mp3'),
        throwsA(
          isA<TaglibException>().having(
            (error) => error.statusCode,
            'statusCode',
            _statusInvalidArgument,
          ),
        ),
      );
    });

    test('saveMp3WithId3v2Version on non-mp3 returns UNSUPPORTED_FORMAT', () {
      final bytes = _readFixtureBytes(nonMp3Fixture.path);
      final session = api.openSession(bytes, nameHint: nonMp3Fixture.nameHint);
      try {
        expect(
          () => session.saveMp3WithId3v2Version(version: Id3v2Version.v24),
          throwsA(
            isA<TaglibException>().having(
              (error) => error.statusCode,
              'statusCode',
              _statusUnsupportedFormat,
            ),
          ),
        );
      } finally {
        session.close();
      }
    });

    test('not-found lyrics and empty clear operations are safe', () {
      final session = api.openSession(sampleMp3Bytes, nameHint: 'sample.mp3');
      try {
        session.clearLyrics(
          language: 'eng',
          description: 'LYRICS',
          id3v2Version: Id3v2Version.v24,
        );
        session.clearLyrics(
          language: 'eng',
          description: 'LYRICS',
          id3v2Version: Id3v2Version.v24,
        );

        expect(
          session.readLyrics(language: 'eng', description: 'LYRICS'),
          isNull,
        );

        session.clearSyncedLyrics(id3v2Version: Id3v2Version.v24);
        session.clearSyncedLyrics(id3v2Version: Id3v2Version.v24);

        expect(session.readSyncedLyrics(), isEmpty);
      } finally {
        session.close();
      }
    });
  });

  group('api convenience consistency (vm)', () {
    test('read convenience APIs match manual session reads', () {
      final convenienceTags = api.readBasicTagsFromBytes(
        sampleMp3Bytes,
        nameHint: 'sample.mp3',
      );
      final manualTags = _readBasicTags(api, sampleMp3Bytes);
      _expectBasicTagsEqual(convenienceTags, manualTags);

      final convenienceIssues = api.scanTextIssuesFromBytes(
        sampleMp3Bytes,
        nameHint: 'sample.mp3',
      );
      final manualIssues = _scanTextIssues(api, sampleMp3Bytes);
      expect(
        convenienceIssues.map(_issueSignature),
        orderedEquals(manualIssues.map(_issueSignature)),
      );

      final readResult = api.readTagsFromBytes(
        sampleMp3Bytes,
        nameHint: 'sample.mp3',
        dirtyTextRepair: false,
      );
      _expectBasicTagsEqual(readResult.tags, manualTags);
      expect(readResult.issues, isEmpty);
      expect(
        readResult.fields.keys,
        containsAll(<String>[
          'title',
          'artist',
          'album',
          'comment',
          'genre',
          'lyrics',
        ]),
      );
    });

    test('writeBasicTagsToBytes matches manual session mutation result', () {
      const tags = BasicTags(
        title: 'Convenience Title',
        artist: 'Convenience Artist',
        album: 'Convenience Album',
        comment: 'Convenience Comment',
        genre: 'Convenience Genre',
        year: 2030,
        track: 9,
      );

      final convenienceOut = api.writeBasicTagsToBytes(
        sampleMp3Bytes,
        tags,
        nameHint: 'sample.mp3',
      );
      final manualOut = _manualWrite(api, sampleMp3Bytes, (session) {
        session.writeBasicTags(tags, id3v2Version: Id3v2Version.v24);
      });

      final convenienceTags = _readBasicTags(api, convenienceOut);
      final manualTags = _readBasicTags(api, manualOut);
      _expectBasicTagsEqual(convenienceTags, manualTags);
      _expectBasicTagsEqual(convenienceTags, tags);
    });

    test('writeLyricsToBytes matches manual session mutation result', () {
      const expectedLyrics =
          'Convenience lyrics line 1\nConvenience lyrics line 2';

      final convenienceOut = api.writeLyricsToBytes(
        sampleMp3Bytes,
        expectedLyrics,
        nameHint: 'sample.mp3',
        language: 'eng',
        description: 'LYRICS',
      );
      final manualOut = _manualWrite(api, sampleMp3Bytes, (session) {
        session.writeLyrics(
          expectedLyrics,
          language: 'eng',
          description: 'LYRICS',
          id3v2Version: Id3v2Version.v24,
        );
      });

      final convenienceSession = api.openSession(
        convenienceOut,
        nameHint: 'sample.mp3',
      );
      final manualSession = api.openSession(manualOut, nameHint: 'sample.mp3');
      try {
        final convenienceLyrics = convenienceSession.readLyrics(
          language: 'eng',
          description: 'LYRICS',
        );
        final manualLyrics = manualSession.readLyrics(
          language: 'eng',
          description: 'LYRICS',
        );
        expect(convenienceLyrics, expectedLyrics);
        expect(convenienceLyrics, manualLyrics);
      } finally {
        convenienceSession.close();
        manualSession.close();
      }
    });

    test('writeSyncedLyricsToBytes matches manual session mutation result', () {
      final track = SyncedLyricsTrack(
        language: 'eng',
        description: 'CONVENIENCE_SYNC',
        type: SyncedLyricsType.lyrics,
        timestampFormat: SyncedLyricsTimestampFormat.milliseconds,
        entries: <SyncedLyricsEntry>[
          SyncedLyricsEntry(time: 0, text: 'a'),
          SyncedLyricsEntry(time: 1000, text: 'b'),
        ],
      );

      final convenienceOut = api.writeSyncedLyricsToBytes(
        sampleMp3Bytes,
        <SyncedLyricsTrack>[track],
        nameHint: 'sample.mp3',
        mergeMode: SyltMergeMode.replaceByKey,
      );
      final manualOut = _manualWrite(api, sampleMp3Bytes, (session) {
        session.writeSyncedLyrics(
          <SyncedLyricsTrack>[track],
          mergeMode: SyltMergeMode.replaceByKey,
          id3v2Version: Id3v2Version.v24,
        );
      });

      final convenienceSession = api.openSession(
        convenienceOut,
        nameHint: 'sample.mp3',
      );
      final manualSession = api.openSession(manualOut, nameHint: 'sample.mp3');
      try {
        final convenienceTrack = _findTrack(
          convenienceSession.readSyncedLyrics(),
          language: track.language,
          description: track.description,
          type: track.type,
        );
        final manualTrack = _findTrack(
          manualSession.readSyncedLyrics(),
          language: track.language,
          description: track.description,
          type: track.type,
        );
        expect(
          convenienceTrack.entries.map((entry) => entry.time).toList(),
          orderedEquals(manualTrack.entries.map((entry) => entry.time)),
        );
        expect(
          convenienceTrack.entries.map((entry) => entry.text).toList(),
          orderedEquals(manualTrack.entries.map((entry) => entry.text)),
        );
      } finally {
        convenienceSession.close();
        manualSession.close();
      }
    });

    test('path convenience APIs read/write in place', () {
      final temp = _createTempAudioFile(sampleMp3Bytes);
      const expectedTags = BasicTags(
        title: 'Path Title',
        artist: 'Path Artist',
        album: 'Path Album',
        comment: 'Path Comment',
        genre: 'Path Genre',
        year: 2027,
        track: 11,
      );

      try {
        final before = api.readBasicTagsFromPath(temp.file.path);
        final baseline = api.readBasicTagsFromBytes(
          sampleMp3Bytes,
          nameHint: 'sample.mp3',
        );
        _expectBasicTagsEqual(before, baseline);

        api.writeBasicTagsToPath(temp.file.path, expectedTags);
        api.writeLyricsToPath(
          temp.file.path,
          'path-lyrics',
          language: 'eng',
          description: 'LYRICS',
        );

        final updatedBytes = temp.file.readAsBytesSync();
        final verify = api.openSession(updatedBytes, nameHint: 'sample.mp3');
        try {
          final tags = verify.readBasicTags();
          _expectBasicTagsEqual(
            tags,
            expectedTags.copyWith(lyrics: 'path-lyrics'),
          );
        } finally {
          verify.close();
        }
      } finally {
        temp.directory.deleteSync(recursive: true);
      }
    });

    test('openFileDescriptor supports read/write session semantics', () {
      final temp = _createTempAudioFile(sampleMp3Bytes);
      try {
        if (Platform.isWindows) {
          expect(
            () => api.openFileDescriptor(0, nameHint: 'sample.mp3'),
            throwsA(
              isA<TaglibException>().having(
                (error) => error.statusCode,
                'statusCode',
                _statusUnsupportedFormat,
              ),
            ),
          );
          return;
        }

        final baseline = api.readBasicTagsFromBytes(
          sampleMp3Bytes,
          nameHint: 'sample.mp3',
        );
        final fd = _openReadWriteFileDescriptor(temp.file.path);
        try {
          final session = api.openFileDescriptor(fd, nameHint: 'sample.mp3');
          try {
            _expectBasicTagsEqual(session.readBasicTags(), baseline);
            session.writeLyrics(
              'fd-lyrics',
              language: 'eng',
              description: 'LYRICS',
              id3v2Version: Id3v2Version.v24,
            );
            expect(session.exportBytes(), isNotEmpty);
          } finally {
            session.close();
          }
        } finally {
          _closeFileDescriptor(fd);
        }

        final verify = api.openSession(
          temp.file.readAsBytesSync(),
          nameHint: 'sample.mp3',
        );
        try {
          expect(
            verify.readLyrics(language: 'eng', description: 'LYRICS'),
            'fd-lyrics',
          );
        } finally {
          verify.close();
        }
      } finally {
        temp.directory.deleteSync(recursive: true);
      }
    });
  });
}
