// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import '../models/audio_properties.dart';
import '../models/basic_tags.dart';
import '../models/id3v2_version.dart';
import '../models/picture_item.dart';
import '../models/property_map.dart';
import '../models/session_capabilities.dart';
import '../models/synced_lyrics.dart';
import '../models/text_issue.dart';

/// Controls how synchronized lyrics are combined with existing tracks.
enum SyltMergeMode {
  /// Replaces tracks with the same language, description, and content type.
  replaceByKey(0),

  /// Appends every supplied track.
  append(1),

  /// Removes all existing synchronized lyrics before writing supplied tracks.
  replaceAll(2);

  /// Creates a mode with the bridge ABI [nativeValue].
  const SyltMergeMode(this.nativeValue);

  /// Numeric value used by the native and WebAssembly bridges.
  final int nativeValue;
}

/// Low-level operations implemented by a single open backend session.
///
/// Applications normally use `TaglibSession`, while custom backend authors
/// implement this interface.
abstract interface class TaglibSessionBackend {
  /// Reads common tag fields.
  BasicTags readBasicTags();

  /// Writes common tag fields.
  void writeBasicTags(BasicTags tags, Id3v2Version id3v2Version);

  /// Reads audio properties, or returns null when unavailable.
  AudioProperties? readAudioProperties();

  /// Reads the generic property map.
  PropertyMap readPropertyMap();

  /// Replaces the generic property map.
  void writePropertyMap(PropertyMap map);

  /// Reads embedded pictures.
  List<PictureItem> readPictures();

  /// Writes embedded [pictures].
  void writePictures(List<PictureItem> pictures, {required bool clearExisting});

  /// Writes embedded pictures from native file paths.
  void writePicturesFromFiles(
    List<PictureFileItem> pictures, {
    required bool clearExisting,
  });

  /// Reads plain lyrics matching optional selectors.
  String? readLyrics({String? language, String? description});

  /// Writes plain lyrics.
  void writeLyrics(
    String text, {
    required String language,
    required String description,
    required Id3v2Version id3v2Version,
  });

  /// Removes plain lyrics matching optional selectors.
  void clearLyrics({
    String? language,
    String? description,
    required Id3v2Version id3v2Version,
  });

  /// Saves an MPEG session using [version].
  void saveMp3WithId3v2Version(Id3v2Version version);

  /// Reads synchronized lyrics.
  List<SyncedLyricsTrack> readSyncedLyrics();

  /// Writes synchronized lyrics.
  void writeSyncedLyrics(
    List<SyncedLyricsTrack> tracks, {
    required SyltMergeMode mergeMode,
    required Id3v2Version id3v2Version,
  });

  /// Removes synchronized lyrics matching [filter].
  void clearSyncedLyrics({
    SyncedLyricsFilter? filter,
    required Id3v2Version id3v2Version,
  });

  /// Finds text fields with suspicious original byte encodings.
  List<TextIssue> scanTextIssues();

  /// Serializes the complete updated file.
  Uint8List exportBytes();

  /// Releases the session and all associated backend resources.
  void close();
}

/// Optional backend capability for probing the actual open format.
abstract interface class TaglibSessionCapabilityProbeBackend {
  /// Returns capabilities detected from the open file.
  SessionCapabilities probeCapabilities();
}

/// Opens TagLib sessions from in-memory bytes.
abstract interface class TaglibBackend {
  /// Opens a session for [bytes].
  TaglibSessionBackend openSession(Uint8List bytes, {String? nameHint});
}

/// Optional native backend capability for opening filesystem paths.
abstract interface class TaglibPathBackend {
  /// Opens a session for the file at [path].
  TaglibSessionBackend openSessionFromPath(String path);
}

/// Optional native backend capability for opening existing file descriptors.
abstract interface class TaglibFileDescriptorBackend {
  /// Opens a session from [fileDescriptor] without taking caller ownership.
  TaglibSessionBackend openSessionFromFileDescriptor(
    int fileDescriptor, {
    String? nameHint,
  });
}
