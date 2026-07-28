// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import '../backend/backend_factory.dart';
import '../backend/taglib_backend.dart';
import '../models/basic_tags.dart';
import '../models/id3v2_version.dart';
import '../models/read_tags_result.dart';
import '../models/synced_lyrics.dart';
import '../models/text_issue.dart';
import 'dirty_text_repair.dart';
import 'taglib_session.dart';

/// High-level entry point for opening sessions and performing one-shot
/// metadata operations.
class TaglibApi {
  /// Creates an API using the platform backend.
  ///
  /// Supply [backend] to provide a custom implementation. [libraryPath] is an
  /// optional native-library fallback and is ignored when [backend] is set.
  /// [repairEngine] customizes dirty text detection and repair.
  TaglibApi({
    TaglibBackend? backend,
    DirtyTextRepairEngine? repairEngine,
    String? libraryPath,
  }) : _backend = backend ?? createDefaultBackend(libraryPath: libraryPath),
       _repairEngine = repairEngine ?? DirtyTextRepairEngine();

  final TaglibBackend _backend;
  final DirtyTextRepairEngine _repairEngine;

  /// Opens an in-memory session for [bytes].
  ///
  /// [nameHint] should contain a filename or extension when available so
  /// format-specific capabilities can be inferred. The caller must close the
  /// returned session.
  TaglibSession openSession(Uint8List bytes, {String? nameHint}) {
    final backendSession = _backend.openSession(bytes, nameHint: nameHint);
    return TaglibSession(backendSession, nameHint: nameHint);
  }

  /// Opens a native session for the file at [path].
  ///
  /// The caller must close the returned session. This operation is unavailable
  /// on Web and on custom backends that do not implement [TaglibPathBackend].
  TaglibSession openSessionFromPath(String path) {
    final backend = _asPathBackend();
    final backendSession = backend.openSessionFromPath(path);
    return TaglibSession(backendSession, nameHint: path);
  }

  /// Opens a native session from [fileDescriptor].
  ///
  /// The caller retains ownership of the supplied descriptor and must close
  /// the returned session. This operation is unavailable on Web and on custom
  /// backends that do not implement [TaglibFileDescriptorBackend].
  TaglibSession openFileDescriptor(int fileDescriptor, {String? nameHint}) {
    final backend = _asFileDescriptorBackend();
    final backendSession = backend.openSessionFromFileDescriptor(
      fileDescriptor,
      nameHint: nameHint,
    );
    return TaglibSession(backendSession, nameHint: nameHint);
  }

  /// Reads basic tags from [bytes] without dirty text repair.
  BasicTags readBasicTagsFromBytes(Uint8List bytes, {String? nameHint}) {
    return _withSession(bytes, nameHint, (session) => session.readBasicTags());
  }

  /// Reads basic tags directly from the file at [path].
  BasicTags readBasicTagsFromPath(String path) {
    return _withPathSession(path, (session) => session.readBasicTags());
  }

  /// Finds text fields whose original bytes may have been decoded incorrectly.
  List<TextIssue> scanTextIssuesFromBytes(Uint8List bytes, {String? nameHint}) {
    return _withSession(bytes, nameHint, (session) => session.scanTextIssues());
  }

  /// Finds potentially misdecoded text fields in the file at [path].
  List<TextIssue> scanTextIssuesFromPath(String path) {
    return _withPathSession(path, (session) => session.scanTextIssues());
  }

  /// Reads tags from [bytes] and optionally repairs likely mojibake.
  ///
  /// [preferredCharsets] limits or prioritizes detector candidates.
  /// [confidenceThreshold] must be finite and between 0 and 1. Set
  /// [dirtyTextRepair] to false to preserve the baseline decoded strings.
  ReadTagsResult readTagsFromBytes(
    Uint8List bytes, {
    String? nameHint,
    bool dirtyTextRepair = true,
    List<String>? preferredCharsets,
    double confidenceThreshold = 0.65,
  }) {
    return _withSession(bytes, nameHint, (session) {
      final rawTags = session.readBasicTags();
      if (!dirtyTextRepair) {
        return ReadTagsResult(
          tags: rawTags,
          fields: _rawFieldMap(rawTags),
          issues: const <TextIssue>[],
        );
      }

      final issues = session.scanTextIssues();
      return _repairEngine.repair(
        rawTags: rawTags,
        issues: issues,
        preferredCharsets: preferredCharsets,
        confidenceThreshold: confidenceThreshold,
      );
    });
  }

  /// Reads tags from [path] and optionally repairs likely mojibake.
  ///
  /// [preferredCharsets] limits or prioritizes detector candidates.
  /// [confidenceThreshold] must be finite and between 0 and 1. Set
  /// [dirtyTextRepair] to false to preserve the baseline decoded strings.
  ReadTagsResult readTagsFromPath(
    String path, {
    bool dirtyTextRepair = true,
    List<String>? preferredCharsets,
    double confidenceThreshold = 0.65,
  }) {
    return _withPathSession(path, (session) {
      final rawTags = session.readBasicTags();
      if (!dirtyTextRepair) {
        return ReadTagsResult(
          tags: rawTags,
          fields: _rawFieldMap(rawTags),
          issues: const <TextIssue>[],
        );
      }

      final issues = session.scanTextIssues();
      return _repairEngine.repair(
        rawTags: rawTags,
        issues: issues,
        preferredCharsets: preferredCharsets,
        confidenceThreshold: confidenceThreshold,
      );
    });
  }

  /// Writes [tags] to [bytes] and returns the complete updated file.
  Uint8List writeBasicTagsToBytes(
    Uint8List bytes,
    BasicTags tags, {
    String? nameHint,
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    return _withSession(bytes, nameHint, (session) {
      session.writeBasicTags(tags, id3v2Version: id3v2Version);
      return session.exportBytes();
    });
  }

  /// Writes [tags] directly to the file at [path].
  void writeBasicTagsToPath(
    String path,
    BasicTags tags, {
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _withPathSession(path, (session) {
      session.writeBasicTags(tags, id3v2Version: id3v2Version);
    });
  }

  /// Writes plain [text] lyrics and returns the complete updated file.
  Uint8List writeLyricsToBytes(
    Uint8List bytes,
    String text, {
    String? nameHint,
    String language = 'eng',
    String description = 'LYRICS',
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    return _withSession(bytes, nameHint, (session) {
      session.writeLyrics(
        text,
        language: language,
        description: description,
        id3v2Version: id3v2Version,
      );
      return session.exportBytes();
    });
  }

  /// Writes plain [text] lyrics directly to the file at [path].
  void writeLyricsToPath(
    String path,
    String text, {
    String language = 'eng',
    String description = 'LYRICS',
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _withPathSession(path, (session) {
      session.writeLyrics(
        text,
        language: language,
        description: description,
        id3v2Version: id3v2Version,
      );
    });
  }

  /// Writes synchronized lyric [tracks] and returns the updated file.
  Uint8List writeSyncedLyricsToBytes(
    Uint8List bytes,
    List<SyncedLyricsTrack> tracks, {
    String? nameHint,
    SyltMergeMode mergeMode = SyltMergeMode.replaceByKey,
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    return _withSession(bytes, nameHint, (session) {
      session.writeSyncedLyrics(
        tracks,
        mergeMode: mergeMode,
        id3v2Version: id3v2Version,
      );
      return session.exportBytes();
    });
  }

  /// Writes synchronized lyric [tracks] directly to the file at [path].
  void writeSyncedLyricsToPath(
    String path,
    List<SyncedLyricsTrack> tracks, {
    SyltMergeMode mergeMode = SyltMergeMode.replaceByKey,
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _withPathSession(path, (session) {
      session.writeSyncedLyrics(
        tracks,
        mergeMode: mergeMode,
        id3v2Version: id3v2Version,
      );
    });
  }

  T _withSession<T>(
    Uint8List bytes,
    String? nameHint,
    T Function(TaglibSession session) run,
  ) {
    final session = openSession(bytes, nameHint: nameHint);
    try {
      return run(session);
    } finally {
      session.close();
    }
  }

  T _withPathSession<T>(String path, T Function(TaglibSession session) run) {
    final session = openSessionFromPath(path);
    try {
      return run(session);
    } finally {
      session.close();
    }
  }

  TaglibPathBackend _asPathBackend() {
    final backend = _backend;
    if (backend is TaglibPathBackend) {
      return backend as TaglibPathBackend;
    }
    throw UnsupportedError(
      'Current backend does not support path sessions. '
      'Use a native backend or bytes-based APIs.',
    );
  }

  TaglibFileDescriptorBackend _asFileDescriptorBackend() {
    final backend = _backend;
    if (backend is TaglibFileDescriptorBackend) {
      return backend as TaglibFileDescriptorBackend;
    }
    throw UnsupportedError(
      'Current backend does not support file descriptor sessions. '
      'Use a native backend or bytes/path-based APIs.',
    );
  }

  Map<String, RepairedTextValue> _rawFieldMap(BasicTags tags) {
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
}
