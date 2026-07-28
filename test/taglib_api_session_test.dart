// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

final class _FakeBackend implements TaglibBackend {
  _FakeBackend(this.sessionFactory);

  final _FakeSessionBackend Function(Uint8List bytes, String? nameHint)
  sessionFactory;
  _FakeSessionBackend? lastSession;

  @override
  TaglibSessionBackend openSession(Uint8List bytes, {String? nameHint}) {
    final session = sessionFactory(bytes, nameHint);
    lastSession = session;
    return session;
  }
}

final class _FakePathFdBackend
    implements TaglibBackend, TaglibPathBackend, TaglibFileDescriptorBackend {
  _FakePathFdBackend({
    required this.bytesFactory,
    required this.pathFactory,
    required this.fdFactory,
  });

  final _FakeSessionBackend Function(Uint8List bytes, String? nameHint)
  bytesFactory;
  final _FakeSessionBackend Function(String path) pathFactory;
  final _FakeSessionBackend Function(int fileDescriptor, String? nameHint)
  fdFactory;
  _FakeSessionBackend? lastSession;
  String? lastPath;
  int? lastFileDescriptor;
  String? lastFdNameHint;

  @override
  TaglibSessionBackend openSession(Uint8List bytes, {String? nameHint}) {
    final session = bytesFactory(bytes, nameHint);
    lastSession = session;
    return session;
  }

  @override
  TaglibSessionBackend openSessionFromPath(String path) {
    lastPath = path;
    final session = pathFactory(path);
    lastSession = session;
    return session;
  }

  @override
  TaglibSessionBackend openSessionFromFileDescriptor(
    int fileDescriptor, {
    String? nameHint,
  }) {
    lastFileDescriptor = fileDescriptor;
    lastFdNameHint = nameHint;
    final session = fdFactory(fileDescriptor, nameHint);
    lastSession = session;
    return session;
  }
}

final class _FakeSessionBackend
    implements TaglibSessionBackend, TaglibSessionCapabilityProbeBackend {
  _FakeSessionBackend({
    required this.basicTags,
    required this.exportedBytes,
    this.capabilities = SessionCapabilities.unknown,
  });

  final BasicTags basicTags;
  final Uint8List exportedBytes;
  final SessionCapabilities capabilities;
  bool closed = false;
  String? lyrics;

  @override
  void clearLyrics({
    String? language,
    String? description,
    required Id3v2Version id3v2Version,
  }) {}

  @override
  void clearSyncedLyrics({
    SyncedLyricsFilter? filter,
    required Id3v2Version id3v2Version,
  }) {}

  @override
  void close() {
    closed = true;
  }

  @override
  Uint8List exportBytes() => exportedBytes;

  @override
  AudioProperties? readAudioProperties() => null;

  @override
  BasicTags readBasicTags() => basicTags;

  @override
  String? readLyrics({String? language, String? description}) => lyrics;

  @override
  List<PictureItem> readPictures() => const <PictureItem>[];

  @override
  PropertyMap readPropertyMap() => PropertyMap.empty();

  @override
  List<SyncedLyricsTrack> readSyncedLyrics() => const <SyncedLyricsTrack>[];

  @override
  List<TextIssue> scanTextIssues() => const <TextIssue>[];

  @override
  SessionCapabilities probeCapabilities() => capabilities;

  @override
  void saveMp3WithId3v2Version(Id3v2Version version) {}

  @override
  void writeBasicTags(BasicTags tags, Id3v2Version id3v2Version) {}

  @override
  void writeLyrics(
    String text, {
    required String language,
    required String description,
    required Id3v2Version id3v2Version,
  }) {
    lyrics = text;
  }

  @override
  void writePictures(
    List<PictureItem> pictures, {
    required bool clearExisting,
  }) {}

  @override
  void writePicturesFromFiles(
    List<PictureFileItem> pictures, {
    required bool clearExisting,
  }) {}

  @override
  void writePropertyMap(PropertyMap map) {}

  @override
  void writeSyncedLyrics(
    List<SyncedLyricsTrack> tracks, {
    required SyltMergeMode mergeMode,
    required Id3v2Version id3v2Version,
  }) {}
}

void main() {
  test('readBasicTagsFromBytes reads from session and closes it', () {
    final backend = _FakeBackend(
      (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(title: 'hello'),
        exportedBytes: Uint8List.fromList(const <int>[1, 2, 3]),
      ),
    );
    final api = TaglibApi(backend: backend);

    final tags = api.readBasicTagsFromBytes(
      Uint8List.fromList(const <int>[1, 2, 3]),
      nameHint: 'sample.mp3',
    );

    expect(tags.title, 'hello');
    expect(backend.lastSession?.closed, isTrue);
  });

  test('writeLyricsToBytes exports mutated bytes and closes session', () {
    final backend = _FakeBackend(
      (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List.fromList(const <int>[9, 8, 7]),
      ),
    );
    final api = TaglibApi(backend: backend);

    final out = api.writeLyricsToBytes(
      Uint8List.fromList(const <int>[1, 2, 3]),
      'new lyrics',
      nameHint: 'sample.mp3',
    );

    expect(out, orderedEquals(const <int>[9, 8, 7]));
    expect(backend.lastSession?.lyrics, 'new lyrics');
    expect(backend.lastSession?.closed, isTrue);
  });

  test('probeCapabilities uses backend runtime probe results', () {
    final backend = _FakeBackend(
      (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List.fromList(const <int>[1]),
        capabilities: const SessionCapabilities(
          plainLyricsWritable: true,
          syncedLyricsWritable: false,
          mp3Id3SaveSupported: false,
          uslt: false,
          lyrics: false,
          mp4Lyr: true,
          wmLyrics: false,
          hintBased: false,
        ),
      ),
    );
    final api = TaglibApi(backend: backend);
    final session = api.openSession(
      Uint8List.fromList(const <int>[1, 2, 3]),
      nameHint: 'demo.mp3',
    );

    try {
      final capabilities = session.probeCapabilities();
      expect(capabilities.plainLyricsWritable, isTrue);
      expect(capabilities.syncedLyricsWritable, isFalse);
      expect(capabilities.mp3Id3SaveSupported, isFalse);
      expect(capabilities.mp4Lyr, isTrue);
      expect(capabilities.hintBased, isFalse);
    } finally {
      session.close();
    }
  });

  test('readBasicTagsFromPath reads from path backend and closes it', () {
    final backend = _FakePathFdBackend(
      bytesFactory: (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
      pathFactory: (_) => _FakeSessionBackend(
        basicTags: const BasicTags(title: 'path-title'),
        exportedBytes: Uint8List.fromList(const <int>[4, 5, 6]),
      ),
      fdFactory: (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
    );
    final api = TaglibApi(backend: backend);

    final tags = api.readBasicTagsFromPath('tmp/audio.mp3');

    expect(tags.title, 'path-title');
    expect(backend.lastPath, 'tmp/audio.mp3');
    expect(backend.lastSession?.closed, isTrue);
  });

  test('openFileDescriptor uses fd backend and closes it', () {
    final backend = _FakePathFdBackend(
      bytesFactory: (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
      pathFactory: (_) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
      fdFactory: (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(title: 'fd-title'),
        exportedBytes: Uint8List(0),
      ),
    );
    final api = TaglibApi(backend: backend);

    final session = api.openFileDescriptor(42, nameHint: 'from-fd.mp3');
    try {
      final tags = session.readBasicTags();
      expect(tags.title, 'fd-title');
      expect(backend.lastFileDescriptor, 42);
      expect(backend.lastFdNameHint, 'from-fd.mp3');
    } finally {
      session.close();
    }
    expect(backend.lastSession?.closed, isTrue);
  });

  test('closed error contains source hint', () {
    final backend = _FakeBackend(
      (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
    );
    final api = TaglibApi(backend: backend);
    final session = api.openSession(
      Uint8List.fromList(<int>[1]),
      nameHint: 'sample.mp3',
    );

    session.close();

    expect(
      () => session.readBasicTags(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('sample.mp3'),
        ),
      ),
    );
  });
  test('openSessionFromPath throws when backend does not support path', () {
    final backend = _FakeBackend(
      (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
    );
    final api = TaglibApi(backend: backend);

    expect(
      () => api.openSessionFromPath('tmp/audio.mp3'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('openFileDescriptor throws when backend does not support fd', () {
    final backend = _FakeBackend(
      (_, _) => _FakeSessionBackend(
        basicTags: const BasicTags(),
        exportedBytes: Uint8List(0),
      ),
    );
    final api = TaglibApi(backend: backend);

    expect(
      () => api.openFileDescriptor(42, nameHint: 'from-fd.mp3'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
