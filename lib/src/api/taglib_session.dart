// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import '../backend/taglib_backend.dart';
import '../models/audio_properties.dart';
import '../models/basic_tags.dart';
import '../models/id3v2_version.dart';
import '../models/picture_item.dart';
import '../models/property_map.dart';
import '../models/session_capabilities.dart';
import '../models/synced_lyrics.dart';
import '../models/text_issue.dart';

/// A mutable metadata session backed by one native or WebAssembly file handle.
///
/// Close the session as soon as its work is complete. A finalizer provides a
/// fallback for abandoned sessions, but deterministic cleanup avoids retaining
/// file and backend memory until garbage collection.
class TaglibSession {
  /// Wraps `backendSession` and records an optional diagnostic [nameHint].
  TaglibSession(this._backendSession, {String? nameHint})
    : sourceHint = nameHint;

  final TaglibSessionBackend _backendSession;

  /// Source name supplied when the session was opened.
  ///
  /// It is used for diagnostics and fallback format capability detection.
  final String? sourceHint;

  bool _closed = false;

  void _ensureOpen() {
    if (_closed) {
      final suffix = sourceHint == null ? '' : ' ($sourceHint)';
      throw StateError('TaglibSession is already closed$suffix.');
    }
  }

  /// Reads the common title, artist, album, and related fields.
  BasicTags readBasicTags() {
    _ensureOpen();
    return _backendSession.readBasicTags();
  }

  /// Writes common tag fields using [id3v2Version] for MPEG files.
  void writeBasicTags(
    BasicTags tags, {
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _ensureOpen();
    _backendSession.writeBasicTags(tags, id3v2Version);
  }

  /// Reads duration, bitrate, sample rate, and channel information.
  ///
  /// Returns null when the format does not expose audio properties.
  AudioProperties? readAudioProperties() {
    _ensureOpen();
    return _backendSession.readAudioProperties();
  }

  /// Reports which lyric and save operations the current format supports.
  SessionCapabilities probeCapabilities() {
    _ensureOpen();
    final backendSession = _backendSession;
    if (backendSession is TaglibSessionCapabilityProbeBackend) {
      return (backendSession as TaglibSessionCapabilityProbeBackend)
          .probeCapabilities();
    }
    return SessionCapabilities.fromNameHint(sourceHint);
  }

  /// Reads the generic TagLib property map.
  PropertyMap readPropertyMap() {
    _ensureOpen();
    return _backendSession.readPropertyMap();
  }

  /// Replaces the generic TagLib property map with [map].
  void writePropertyMap(PropertyMap map) {
    _ensureOpen();
    _backendSession.writePropertyMap(map);
  }

  /// Reads embedded pictures in their stored order.
  List<PictureItem> readPictures() {
    _ensureOpen();
    return _backendSession.readPictures();
  }

  /// Writes [pictures], optionally removing existing pictures first.
  void writePictures(List<PictureItem> pictures, {bool clearExisting = true}) {
    _ensureOpen();
    _backendSession.writePictures(pictures, clearExisting: clearExisting);
  }

  /// Writes pictures directly from local file paths.
  ///
  /// This native-only operation avoids loading each complete image into the
  /// Dart heap. It throws [UnsupportedError] on Web.
  void writePicturesFromFiles(
    List<PictureFileItem> pictures, {
    bool clearExisting = true,
  }) {
    _ensureOpen();
    _backendSession.writePicturesFromFiles(
      pictures,
      clearExisting: clearExisting,
    );
  }

  /// Reads plain lyrics matching the optional language and description.
  String? readLyrics({String? language, String? description}) {
    _ensureOpen();
    return _backendSession.readLyrics(
      language: language,
      description: description,
    );
  }

  /// Writes plain [text] lyrics.
  void writeLyrics(
    String text, {
    String language = 'eng',
    String description = 'LYRICS',
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _ensureOpen();
    _backendSession.writeLyrics(
      text,
      language: language,
      description: description,
      id3v2Version: id3v2Version,
    );
  }

  /// Removes plain lyrics matching the optional language and description.
  void clearLyrics({
    String? language,
    String? description,
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _ensureOpen();
    _backendSession.clearLyrics(
      language: language,
      description: description,
      id3v2Version: id3v2Version,
    );
  }

  /// Saves an MPEG file using the requested ID3v2 [version].
  void saveMp3WithId3v2Version({Id3v2Version version = Id3v2Version.v24}) {
    _ensureOpen();
    _backendSession.saveMp3WithId3v2Version(version);
  }

  /// Reads every synchronized lyrics track.
  List<SyncedLyricsTrack> readSyncedLyrics() {
    _ensureOpen();
    return _backendSession.readSyncedLyrics();
  }

  /// Writes synchronized lyric [tracks] using [mergeMode].
  void writeSyncedLyrics(
    List<SyncedLyricsTrack> tracks, {
    SyltMergeMode mergeMode = SyltMergeMode.replaceByKey,
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _ensureOpen();
    _backendSession.writeSyncedLyrics(
      tracks,
      mergeMode: mergeMode,
      id3v2Version: id3v2Version,
    );
  }

  /// Removes synchronized lyrics matching [filter], or all tracks when null.
  void clearSyncedLyrics({
    SyncedLyricsFilter? filter,
    Id3v2Version id3v2Version = Id3v2Version.v24,
  }) {
    _ensureOpen();
    _backendSession.clearSyncedLyrics(
      filter: filter,
      id3v2Version: id3v2Version,
    );
  }

  /// Returns metadata fields that may have been decoded with the wrong charset.
  List<TextIssue> scanTextIssues() {
    _ensureOpen();
    return _backendSession.scanTextIssues();
  }

  /// Serializes the current session into a new complete file byte array.
  Uint8List exportBytes() {
    _ensureOpen();
    return _backendSession.exportBytes();
  }

  /// Releases backend resources.
  ///
  /// Calling this method more than once has no effect. Every other operation
  /// throws [StateError] after the session is closed.
  void close() {
    if (_closed) {
      return;
    }
    _backendSession.close();
    _closed = true;
  }
}
