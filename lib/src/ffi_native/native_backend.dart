// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../api/taglib_exception.dart';
import '../backend/taglib_backend.dart';
import '../models/audio_properties.dart';
import '../models/basic_tags.dart';
import '../models/id3v2_version.dart';
import '../models/picture_item.dart';
import '../models/property_map.dart';
import '../models/session_capabilities.dart';
import '../models/synced_lyrics.dart';
import '../models/text_issue.dart';
import 'taglib_bridge_ffi.dart';

String nativeBridgeLibraryFileNameForOperatingSystem(String operatingSystem) {
  return switch (operatingSystem) {
    'windows' => 'taglib_bridge.dll',
    'macos' || 'ios' => 'libtaglib_bridge.dylib',
    'linux' || 'android' => 'libtaglib_bridge.so',
    _ => throw UnsupportedError(
      'Unsupported platform for taglib_bridge: $operatingSystem',
    ),
  };
}

DynamicLibrary openNativeBridgeLibraryByFileName({String? operatingSystem}) {
  final resolvedOperatingSystem = operatingSystem ?? Platform.operatingSystem;
  return DynamicLibrary.open(
    nativeBridgeLibraryFileNameForOperatingSystem(resolvedOperatingSystem),
  );
}

final class NativeTaglibBackend
    implements TaglibBackend, TaglibPathBackend, TaglibFileDescriptorBackend {
  NativeTaglibBackend({String? libraryPath, DynamicLibrary? dynamicLibrary})
    : _ffi = _createBridgeBindings(
        libraryPath: libraryPath,
        dynamicLibrary: dynamicLibrary,
      ) {
    // 同一个 backend 的会话共用 finalizer，避免批处理时为每个会话额外创建
    // NativeFinalizer 对象；会话仍各自注册独立的 native 指针和解绑令牌。
    _sessionFinalizer = NativeFinalizer(_ffi.finalizeSession.cast());
  }

  final TaglibBridgeFfi _ffi;
  late final NativeFinalizer _sessionFinalizer;

  static const int _statusOk = 0;

  static TaglibBridgeFfi _createBridgeBindings({
    required String? libraryPath,
    required DynamicLibrary? dynamicLibrary,
  }) {
    if (dynamicLibrary != null) {
      final ffi = TaglibBridgeFfi(dynamicLibrary);
      ffi.validateBridge(source: 'provided DynamicLibrary');
      return ffi;
    }

    final explicitPath =
        libraryPath ?? Platform.environment['TAGLIB_BRIDGE_LIB'];
    if (explicitPath != null && explicitPath.isNotEmpty) {
      final ffi = TaglibBridgeFfi(DynamicLibrary.open(explicitPath));
      ffi.validateBridge(source: explicitPath);
      return ffi;
    }

    try {
      final ffi = TaglibBridgeFfi.nativeAsset();
      // Force a symbol resolution probe so missing/misconfigured assets fail
      // early and can still fall back to filename-based loading.
      ffi.validateBridge(source: 'native asset');
      ffi.statusMessage(_statusOk);
      return ffi;
    } on Object catch (nativeAssetError) {
      try {
        final ffi = TaglibBridgeFfi(openNativeBridgeLibraryByFileName());
        ffi.validateBridge(source: 'filename fallback');
        return ffi;
      } on Object catch (fallbackError) {
        throw StateError(
          'Unable to load taglib_bridge for ${Platform.operatingSystem}. '
          'nativeAsset() failed with: $nativeAssetError\n'
          'filename fallback failed with: $fallbackError',
        );
      }
    }
  }

  @override
  TaglibSessionBackend openSession(Uint8List bytes, {String? nameHint}) {
    if (bytes.isEmpty) {
      throw TaglibException(1, 'invalid argument');
    }

    final bytesPtr = calloc<Uint8>(bytes.length);
    final nameHintPtr = _toNativeNullable(nameHint);
    final sessionOutPtr = calloc<Pointer<TlbSession>>();
    try {
      bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      final status = _ffi.openSessionFromBytes(
        bytesPtr,
        bytes.length,
        nameHintPtr,
        sessionOutPtr,
      );
      _throwIfError(_ffi, status);
      return _NativeTaglibSession(_ffi, _sessionFinalizer, sessionOutPtr.value);
    } finally {
      calloc.free(bytesPtr);
      _freeNullable(nameHintPtr);
      calloc.free(sessionOutPtr);
    }
  }

  @override
  TaglibSessionBackend openSessionFromPath(String path) {
    if (path.isEmpty) {
      throw TaglibException(1, 'invalid argument');
    }

    final pathPtr = path.toNativeUtf8();
    final sessionOutPtr = calloc<Pointer<TlbSession>>();
    try {
      final status = _ffi.openSessionFromPath(pathPtr, sessionOutPtr);
      _throwIfError(_ffi, status);
      return _NativeTaglibSession(_ffi, _sessionFinalizer, sessionOutPtr.value);
    } finally {
      calloc.free(pathPtr);
      calloc.free(sessionOutPtr);
    }
  }

  @override
  TaglibSessionBackend openSessionFromFileDescriptor(
    int fileDescriptor, {
    String? nameHint,
  }) {
    if (fileDescriptor < 0) {
      throw TaglibException(1, 'invalid argument');
    }

    final nameHintPtr = _toNativeNullable(nameHint);
    final sessionOutPtr = calloc<Pointer<TlbSession>>();
    try {
      final status = _ffi.openSessionFromFd(
        fileDescriptor,
        nameHintPtr,
        sessionOutPtr,
      );
      _throwIfError(_ffi, status);
      return _NativeTaglibSession(_ffi, _sessionFinalizer, sessionOutPtr.value);
    } finally {
      _freeNullable(nameHintPtr);
      calloc.free(sessionOutPtr);
    }
  }

  static void _throwIfError(TaglibBridgeFfi ffi, int status) {
    if (status == _statusOk) {
      return;
    }
    final messagePtr = ffi.statusMessage(status);
    final message = messagePtr == nullptr
        ? 'Unknown error'
        : messagePtr.toDartString();
    throw TaglibException(status, message);
  }

  static Pointer<Utf8> _toNativeNullable(String? value) {
    if (value == null) {
      return nullptr;
    }
    return value.toNativeUtf8();
  }

  static void _freeNullable(Pointer<Utf8> pointer) {
    if (pointer != nullptr) {
      calloc.free(pointer);
    }
  }

  static String? _readNullableString(Pointer<Utf8> pointer) {
    if (pointer == nullptr) {
      return null;
    }
    return pointer.toDartString();
  }

  static Uint8List _copyBytes(Pointer<Uint8> pointer, int length) {
    if (pointer == nullptr || length <= 0) {
      return Uint8List(0);
    }
    return Uint8List.fromList(pointer.asTypedList(length));
  }

  static String _languageFromArray(Array<Uint8> language) {
    final bytes = <int>[];
    for (var i = 0; i < 3; i++) {
      final value = language[i];
      if (value == 0) {
        break;
      }
      bytes.add(value);
    }
    if (bytes.isEmpty) {
      return '';
    }
    return utf8.decode(bytes, allowMalformed: true).trim();
  }
}

final class _NativeTaglibSession
    implements
        TaglibSessionBackend,
        TaglibSessionCapabilityProbeBackend,
        Finalizable {
  _NativeTaglibSession(this._ffi, this._finalizer, this._session) {
    // 显式 close 是确定释放路径；finalizer 只兜底调用者遗漏关闭的情况。
    _finalizer.attach(this, _session.cast<Void>(), detach: this);
  }

  final TaglibBridgeFfi _ffi;
  final NativeFinalizer _finalizer;
  Pointer<TlbSession> _session;
  bool _closed = false;

  static const int _statusNotFound = 4;

  void _ensureOpen() {
    if (_closed || _session == nullptr) {
      throw StateError('Taglib session is already closed.');
    }
  }

  void _throwIfError(int status) {
    NativeTaglibBackend._throwIfError(_ffi, status);
  }

  @override
  BasicTags readBasicTags() {
    _ensureOpen();
    final outPtr = calloc<TlbBasicTags>();
    try {
      final status = _ffi.readBasicTags(_session, outPtr);
      _throwIfError(status);
      final tags = outPtr.ref;
      return BasicTags(
        title: NativeTaglibBackend._readNullableString(tags.title),
        artist: NativeTaglibBackend._readNullableString(tags.artist),
        album: NativeTaglibBackend._readNullableString(tags.album),
        comment: NativeTaglibBackend._readNullableString(tags.comment),
        genre: NativeTaglibBackend._readNullableString(tags.genre),
        lyrics: NativeTaglibBackend._readNullableString(tags.lyrics),
        year: tags.year,
        track: tags.track,
      );
    } finally {
      _ffi.freeBasicTags(outPtr);
      calloc.free(outPtr);
    }
  }

  @override
  void writeBasicTags(BasicTags tags, Id3v2Version id3v2Version) {
    _ensureOpen();
    final nativeTags = calloc<TlbBasicTags>();
    final allocations = <Pointer<Void>>[];
    Pointer<Utf8> toNative(String? value) {
      final ptr = NativeTaglibBackend._toNativeNullable(value);
      if (ptr != nullptr) {
        allocations.add(ptr.cast<Void>());
      }
      return ptr;
    }

    try {
      // writeBasicTags 传入的是 Dart 分配的输入结构，不能交给 native 的
      // tlb_free_basic_tags() 释放；该释放函数只属于 readBasicTags 输出结构。
      nativeTags.ref.title = toNative(tags.title);
      nativeTags.ref.artist = toNative(tags.artist);
      nativeTags.ref.album = toNative(tags.album);
      nativeTags.ref.comment = toNative(tags.comment);
      nativeTags.ref.genre = toNative(tags.genre);
      nativeTags.ref.lyrics = toNative(tags.lyrics);
      nativeTags.ref.year = tags.year;
      nativeTags.ref.track = tags.track;
      final status = _ffi.writeBasicTags(
        _session,
        nativeTags,
        id3v2Version.nativeValue,
      );
      _throwIfError(status);
    } finally {
      for (final ptr in allocations.reversed) {
        calloc.free(ptr);
      }
      calloc.free(nativeTags);
    }
  }

  @override
  AudioProperties? readAudioProperties() {
    _ensureOpen();
    final outPtr = calloc<TlbAudioProperties>();
    try {
      final status = _ffi.readAudioProperties(_session, outPtr);
      if (status == _statusNotFound) {
        return null;
      }
      _throwIfError(status);
      final row = outPtr.ref;
      return AudioProperties(
        lengthSeconds: row.lengthSeconds,
        bitrateKbps: row.bitrateKbps,
        sampleRate: row.sampleRate,
        channels: row.channels,
      );
    } finally {
      calloc.free(outPtr);
    }
  }

  @override
  SessionCapabilities probeCapabilities() {
    _ensureOpen();
    final outPtr = calloc<TlbSessionCapabilities>();
    try {
      final status = _ffi.probeCapabilities(_session, outPtr);
      _throwIfError(status);
      final capabilities = outPtr.ref;
      return SessionCapabilities(
        plainLyricsWritable: capabilities.plainLyricsWritable != 0,
        syncedLyricsWritable: capabilities.syncedLyricsWritable != 0,
        mp3Id3SaveSupported: capabilities.mp3Id3SaveSupported != 0,
        uslt: capabilities.uslt != 0,
        lyrics: capabilities.lyrics != 0,
        mp4Lyr: capabilities.mp4Lyr != 0,
        wmLyrics: capabilities.wmLyrics != 0,
        hintBased: capabilities.hintBased != 0,
      );
    } finally {
      calloc.free(outPtr);
    }
  }

  @override
  PropertyMap readPropertyMap() {
    _ensureOpen();
    final outPtr = calloc<TlbPropertyMap>();
    try {
      final status = _ffi.readPropertyMap(_session, outPtr);
      _throwIfError(status);
      final items = <PropertyItem>[];
      final count = outPtr.ref.itemCount;
      for (var i = 0; i < count; i++) {
        final item = outPtr.ref.items[i];
        final key = NativeTaglibBackend._readNullableString(item.key) ?? '';
        final values = <String>[];
        for (var j = 0; j < item.valueCount; j++) {
          values.add(
            NativeTaglibBackend._readNullableString(item.values[j]) ?? '',
          );
        }
        items.add(PropertyItem(key: key, values: values));
      }
      return PropertyMap(items: items);
    } finally {
      _ffi.freePropertyMap(outPtr);
      calloc.free(outPtr);
    }
  }

  @override
  void writePropertyMap(PropertyMap map) {
    _ensureOpen();
    final nativeMap = calloc<TlbPropertyMap>();
    final allocations = <Pointer<Void>>[];
    try {
      nativeMap.ref.itemCount = map.items.length;
      if (map.items.isNotEmpty) {
        final nativeItems = calloc<TlbPropertyItem>(map.items.length);
        allocations.add(nativeItems.cast<Void>());
        nativeMap.ref.items = nativeItems;

        for (var i = 0; i < map.items.length; i++) {
          final item = map.items[i];
          final nativeItem = nativeItems[i];
          final keyPtr = item.key.toNativeUtf8();
          allocations.add(keyPtr.cast<Void>());
          nativeItem.key = keyPtr;
          nativeItem.valueCount = item.values.length;

          if (item.values.isNotEmpty) {
            final valuePtrs = calloc<Pointer<Utf8>>(item.values.length);
            allocations.add(valuePtrs.cast<Void>());
            nativeItem.values = valuePtrs;
            for (var j = 0; j < item.values.length; j++) {
              final valuePtr = item.values[j].toNativeUtf8();
              allocations.add(valuePtr.cast<Void>());
              valuePtrs[j] = valuePtr;
            }
          } else {
            nativeItem.values = nullptr;
          }
        }
      } else {
        nativeMap.ref.items = nullptr;
      }

      final status = _ffi.writePropertyMap(_session, nativeMap);
      _throwIfError(status);
    } finally {
      for (final ptr in allocations.reversed) {
        calloc.free(ptr);
      }
      calloc.free(nativeMap);
    }
  }

  @override
  List<PictureItem> readPictures() {
    _ensureOpen();
    final outPtr = calloc<TlbPictureList>();
    try {
      final status = _ffi.readPictures(_session, outPtr);
      _throwIfError(status);
      final pictures = <PictureItem>[];
      final count = outPtr.ref.itemCount;
      for (var i = 0; i < count; i++) {
        final item = outPtr.ref.items[i];
        pictures.add(
          PictureItem(
            mimeType: NativeTaglibBackend._readNullableString(item.mimeType),
            description: NativeTaglibBackend._readNullableString(
              item.description,
            ),
            pictureType: NativeTaglibBackend._readNullableString(
              item.pictureType,
            ),
            data: NativeTaglibBackend._copyBytes(item.data, item.dataLength),
          ),
        );
      }
      return pictures;
    } finally {
      _ffi.freePictureList(outPtr);
      calloc.free(outPtr);
    }
  }

  @override
  void writePictures(
    List<PictureItem> pictures, {
    required bool clearExisting,
  }) {
    _ensureOpen();
    final nativeList = calloc<TlbPictureList>();
    final allocations = <Pointer<Void>>[];
    try {
      nativeList.ref.itemCount = pictures.length;
      if (pictures.isNotEmpty) {
        final nativeItems = calloc<TlbPictureItem>(pictures.length);
        allocations.add(nativeItems.cast<Void>());
        nativeList.ref.items = nativeItems;

        for (var i = 0; i < pictures.length; i++) {
          final item = pictures[i];
          final nativeItem = nativeItems[i];
          nativeItem.mimeType = NativeTaglibBackend._toNativeNullable(
            item.mimeType,
          );
          nativeItem.description = NativeTaglibBackend._toNativeNullable(
            item.description,
          );
          nativeItem.pictureType = NativeTaglibBackend._toNativeNullable(
            item.pictureType,
          );

          if (nativeItem.mimeType != nullptr) {
            allocations.add(nativeItem.mimeType.cast<Void>());
          }
          if (nativeItem.description != nullptr) {
            allocations.add(nativeItem.description.cast<Void>());
          }
          if (nativeItem.pictureType != nullptr) {
            allocations.add(nativeItem.pictureType.cast<Void>());
          }

          nativeItem.dataLength = item.data.length;
          if (item.data.isNotEmpty) {
            final dataPtr = calloc<Uint8>(item.data.length);
            allocations.add(dataPtr.cast<Void>());
            dataPtr.asTypedList(item.data.length).setAll(0, item.data);
            nativeItem.data = dataPtr;
          } else {
            nativeItem.data = nullptr;
          }
        }
      } else {
        nativeList.ref.items = nullptr;
      }

      final status = _ffi.writePictures(
        _session,
        nativeList,
        clearExisting ? 1 : 0,
      );
      _throwIfError(status);
    } finally {
      for (final ptr in allocations.reversed) {
        calloc.free(ptr);
      }
      calloc.free(nativeList);
    }
  }

  @override
  void writePicturesFromFiles(
    List<PictureFileItem> pictures, {
    required bool clearExisting,
  }) {
    _ensureOpen();
    final nativeList = calloc<TlbPictureFileList>();
    final allocations = <Pointer<Void>>[];
    try {
      nativeList.ref.itemCount = pictures.length;
      if (pictures.isEmpty) {
        nativeList.ref.items = nullptr;
      } else {
        final nativeItems = calloc<TlbPictureFileItem>(pictures.length);
        allocations.add(nativeItems.cast<Void>());
        nativeList.ref.items = nativeItems;
        for (var i = 0; i < pictures.length; i++) {
          final PictureFileItem item = pictures[i];
          final TlbPictureFileItem nativeItem = nativeItems[i];
          nativeItem.path = item.path.toNativeUtf8();
          nativeItem.mimeType = NativeTaglibBackend._toNativeNullable(
            item.mimeType,
          );
          nativeItem.description = NativeTaglibBackend._toNativeNullable(
            item.description,
          );
          nativeItem.pictureType = NativeTaglibBackend._toNativeNullable(
            item.pictureType,
          );
          allocations.add(nativeItem.path.cast<Void>());
          for (final Pointer<Utf8> pointer in <Pointer<Utf8>>[
            nativeItem.mimeType,
            nativeItem.description,
            nativeItem.pictureType,
          ]) {
            if (pointer != nullptr) {
              allocations.add(pointer.cast<Void>());
            }
          }
        }
      }
      final int status = _ffi.writePictureFiles(
        _session,
        nativeList,
        clearExisting ? 1 : 0,
      );
      _throwIfError(status);
    } finally {
      for (final Pointer<Void> pointer in allocations.reversed) {
        calloc.free(pointer);
      }
      calloc.free(nativeList);
    }
  }

  @override
  String? readLyrics({String? language, String? description}) {
    _ensureOpen();
    final languagePtr = NativeTaglibBackend._toNativeNullable(language);
    final descriptionPtr = NativeTaglibBackend._toNativeNullable(description);
    final outPtr = calloc<Pointer<Utf8>>();
    try {
      final status = _ffi.readLyrics(
        _session,
        languagePtr,
        descriptionPtr,
        outPtr,
      );
      if (status == _statusNotFound) {
        return null;
      }
      _throwIfError(status);

      if (outPtr.value == nullptr) {
        return '';
      }

      final text = outPtr.value.toDartString();
      _ffi.freeString(outPtr.value);
      outPtr.value = nullptr;
      return text;
    } finally {
      if (outPtr.value != nullptr) {
        _ffi.freeString(outPtr.value);
      }
      calloc.free(outPtr);
      NativeTaglibBackend._freeNullable(languagePtr);
      NativeTaglibBackend._freeNullable(descriptionPtr);
    }
  }

  @override
  void writeLyrics(
    String text, {
    required String language,
    required String description,
    required Id3v2Version id3v2Version,
  }) {
    _ensureOpen();
    final textPtr = text.toNativeUtf8();
    final languagePtr = language.toNativeUtf8();
    final descriptionPtr = description.toNativeUtf8();
    try {
      final status = _ffi.writeLyrics(
        _session,
        textPtr,
        languagePtr,
        descriptionPtr,
        id3v2Version.nativeValue,
      );
      _throwIfError(status);
    } finally {
      calloc.free(textPtr);
      calloc.free(languagePtr);
      calloc.free(descriptionPtr);
    }
  }

  @override
  void clearLyrics({
    String? language,
    String? description,
    required Id3v2Version id3v2Version,
  }) {
    _ensureOpen();
    final languagePtr = NativeTaglibBackend._toNativeNullable(language);
    final descriptionPtr = NativeTaglibBackend._toNativeNullable(description);
    try {
      final status = _ffi.clearLyrics(
        _session,
        languagePtr,
        descriptionPtr,
        id3v2Version.nativeValue,
      );
      _throwIfError(status);
    } finally {
      NativeTaglibBackend._freeNullable(languagePtr);
      NativeTaglibBackend._freeNullable(descriptionPtr);
    }
  }

  @override
  void saveMp3WithId3v2Version(Id3v2Version version) {
    _ensureOpen();
    final status = _ffi.saveWithId3v2Version(_session, version.nativeValue);
    _throwIfError(status);
  }

  @override
  List<SyncedLyricsTrack> readSyncedLyrics() {
    _ensureOpen();
    final outPtr = calloc<TlbSyltTrackList>();
    try {
      final status = _ffi.readSylt(_session, outPtr);
      if (status == _statusNotFound) {
        return const <SyncedLyricsTrack>[];
      }
      _throwIfError(status);

      final tracks = <SyncedLyricsTrack>[];
      final trackCount = outPtr.ref.trackCount;
      for (var i = 0; i < trackCount; i++) {
        final track = outPtr.ref.tracks[i];
        final language = NativeTaglibBackend._languageFromArray(track.language);
        final entries = <SyncedLyricsEntry>[];
        for (var j = 0; j < track.entryCount; j++) {
          final entry = track.entries[j];
          entries.add(
            SyncedLyricsEntry(
              time: entry.time,
              text: NativeTaglibBackend._readNullableString(entry.text) ?? '',
            ),
          );
        }

        tracks.add(
          SyncedLyricsTrack(
            language: language,
            description:
                NativeTaglibBackend._readNullableString(track.description) ??
                '',
            type: SyncedLyricsType.fromNative(track.type),
            timestampFormat: SyncedLyricsTimestampFormat.fromNative(
              track.timestampFormat,
            ),
            entries: entries,
          ),
        );
      }
      return tracks;
    } finally {
      _ffi.freeSyltTrackList(outPtr);
      calloc.free(outPtr);
    }
  }

  @override
  void writeSyncedLyrics(
    List<SyncedLyricsTrack> tracks, {
    required SyltMergeMode mergeMode,
    required Id3v2Version id3v2Version,
  }) {
    _ensureOpen();
    Pointer<TlbSyltTrack> nativeTracks = nullptr;
    final allocations = <Pointer<Void>>[];

    try {
      if (tracks.isNotEmpty) {
        nativeTracks = calloc<TlbSyltTrack>(tracks.length);
        allocations.add(nativeTracks.cast<Void>());
      }

      for (var i = 0; i < tracks.length; i++) {
        final sourceTrack = tracks[i];
        final nativeTrack = nativeTracks[i];

        final languageBytes = utf8.encode(sourceTrack.language);
        for (var p = 0; p < 4; p++) {
          nativeTrack.language[p] = p < 3 && p < languageBytes.length
              ? languageBytes[p]
              : 0;
        }

        final descriptionPtr = sourceTrack.description.toNativeUtf8();
        allocations.add(descriptionPtr.cast<Void>());
        nativeTrack.description = descriptionPtr;
        nativeTrack.type = sourceTrack.type.nativeValue;
        nativeTrack.timestampFormat = sourceTrack.timestampFormat.nativeValue;

        if (sourceTrack.entries.isNotEmpty) {
          final nativeEntries = calloc<TlbSyltEntry>(
            sourceTrack.entries.length,
          );
          allocations.add(nativeEntries.cast<Void>());
          nativeTrack.entries = nativeEntries;
          nativeTrack.entryCount = sourceTrack.entries.length;

          for (var j = 0; j < sourceTrack.entries.length; j++) {
            final entry = sourceTrack.entries[j];
            nativeEntries[j].time = entry.time;
            final textPtr = entry.text.toNativeUtf8();
            allocations.add(textPtr.cast<Void>());
            nativeEntries[j].text = textPtr;
          }
        } else {
          nativeTrack.entries = nullptr;
          nativeTrack.entryCount = 0;
        }
      }

      final status = _ffi.writeSylt(
        _session,
        nativeTracks,
        tracks.length,
        mergeMode.nativeValue,
        id3v2Version.nativeValue,
      );
      _throwIfError(status);
    } finally {
      for (final pointer in allocations.reversed) {
        calloc.free(pointer);
      }
    }
  }

  @override
  void clearSyncedLyrics({
    SyncedLyricsFilter? filter,
    required Id3v2Version id3v2Version,
  }) {
    _ensureOpen();
    Pointer<TlbSyltFilter> nativeFilter = nullptr;
    Pointer<Utf8> languagePtr = nullptr;
    Pointer<Utf8> descriptionPtr = nullptr;
    try {
      if (filter != null) {
        nativeFilter = calloc<TlbSyltFilter>();
        languagePtr = NativeTaglibBackend._toNativeNullable(filter.language);
        descriptionPtr = NativeTaglibBackend._toNativeNullable(
          filter.description,
        );
        nativeFilter.ref.language = languagePtr;
        nativeFilter.ref.description = descriptionPtr;
        nativeFilter.ref.type = filter.type?.nativeValue ?? -1;
      }

      final status = _ffi.clearSylt(
        _session,
        nativeFilter,
        id3v2Version.nativeValue,
      );
      _throwIfError(status);
    } finally {
      if (nativeFilter != nullptr) {
        calloc.free(nativeFilter);
      }
      NativeTaglibBackend._freeNullable(languagePtr);
      NativeTaglibBackend._freeNullable(descriptionPtr);
    }
  }

  @override
  List<TextIssue> scanTextIssues() {
    _ensureOpen();
    final outPtr = calloc<TlbTextIssueList>();
    try {
      final status = _ffi.scanTextIssues(_session, outPtr);
      _throwIfError(status);

      final issues = <TextIssue>[];
      final issueCount = outPtr.ref.issueCount;
      for (var i = 0; i < issueCount; i++) {
        final issue = outPtr.ref.issues[i];
        issues.add(
          TextIssue(
            source: TextIssueSource.fromNative(issue.source),
            fieldPath: NativeTaglibBackend._readNullableString(issue.fieldPath),
            frameId: NativeTaglibBackend._readNullableString(issue.frameId),
            language: NativeTaglibBackend._readNullableString(issue.language),
            description: NativeTaglibBackend._readNullableString(
              issue.description,
            ),
            rawBytes: NativeTaglibBackend._copyBytes(
              issue.rawBytes,
              issue.rawBytesLength,
            ),
            baselineDecoded: NativeTaglibBackend._readNullableString(
              issue.baselineDecoded,
            ),
          ),
        );
      }
      return issues;
    } finally {
      _ffi.freeTextIssueList(outPtr);
      calloc.free(outPtr);
    }
  }

  @override
  Uint8List exportBytes() {
    _ensureOpen();
    final outBytesPtr = calloc<Pointer<Uint8>>();
    final outLenPtr = calloc<Uint32>();
    try {
      final status = _ffi.exportSessionBytes(_session, outBytesPtr, outLenPtr);
      _throwIfError(status);
      final bytes = NativeTaglibBackend._copyBytes(
        outBytesPtr.value,
        outLenPtr.value,
      );
      return bytes;
    } finally {
      // Dart 堆复制失败时也必须释放 native 输出，避免批处理任务累积泄漏。
      if (outBytesPtr.value != nullptr) {
        _ffi.freeBytes(outBytesPtr.value);
      }
      calloc.free(outBytesPtr);
      calloc.free(outLenPtr);
    }
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    final sessionPtrPtr = calloc<Pointer<TlbSession>>();
    try {
      sessionPtrPtr.value = _session;
      final status = _ffi.closeSession(sessionPtrPtr);
      _throwIfError(status);
      _finalizer.detach(this);
      _session = nullptr;
      _closed = true;
    } finally {
      calloc.free(sessionPtrPtr);
    }
  }
}
