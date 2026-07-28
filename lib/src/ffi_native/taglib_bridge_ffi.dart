// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

// ignore_for_file: library_private_types_in_public_api, public_member_api_docs

@DefaultAsset('package:dart_taglib/src/ffi_native/taglib_bridge_ffi.dart')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

final class TlbSession extends Opaque {}

final class TlbBasicTags extends Struct {
  external Pointer<Utf8> title;
  external Pointer<Utf8> artist;
  external Pointer<Utf8> album;
  external Pointer<Utf8> comment;
  external Pointer<Utf8> genre;
  external Pointer<Utf8> lyrics;

  @Uint32()
  external int year;

  @Uint32()
  external int track;
}

final class TlbAudioProperties extends Struct {
  @Int32()
  external int lengthSeconds;

  @Int32()
  external int bitrateKbps;

  @Int32()
  external int sampleRate;

  @Int32()
  external int channels;
}

final class TlbSessionCapabilities extends Struct {
  @Uint8()
  external int plainLyricsWritable;

  @Uint8()
  external int syncedLyricsWritable;

  @Uint8()
  external int mp3Id3SaveSupported;

  @Uint8()
  external int uslt;

  @Uint8()
  external int lyrics;

  @Uint8()
  external int mp4Lyr;

  @Uint8()
  external int wmLyrics;

  @Uint8()
  external int hintBased;
}

final class TlbPropertyItem extends Struct {
  external Pointer<Utf8> key;
  external Pointer<Pointer<Utf8>> values;

  @Uint32()
  external int valueCount;
}

final class TlbPropertyMap extends Struct {
  external Pointer<TlbPropertyItem> items;

  @Uint32()
  external int itemCount;
}

final class TlbPictureItem extends Struct {
  external Pointer<Utf8> mimeType;
  external Pointer<Utf8> description;
  external Pointer<Utf8> pictureType;
  external Pointer<Uint8> data;

  @Uint32()
  external int dataLength;
}

final class TlbPictureList extends Struct {
  external Pointer<TlbPictureItem> items;

  @Uint32()
  external int itemCount;
}

final class TlbPictureFileItem extends Struct {
  external Pointer<Utf8> path;
  external Pointer<Utf8> mimeType;
  external Pointer<Utf8> description;
  external Pointer<Utf8> pictureType;
}

final class TlbPictureFileList extends Struct {
  external Pointer<TlbPictureFileItem> items;

  @Uint32()
  external int itemCount;
}

final class TlbSyltEntry extends Struct {
  @Uint32()
  external int time;
  external Pointer<Utf8> text;
}

final class TlbSyltTrack extends Struct {
  @Array(4)
  external Array<Uint8> language;
  external Pointer<Utf8> description;

  @Uint8()
  external int type;

  @Uint8()
  external int timestampFormat;

  external Pointer<TlbSyltEntry> entries;

  @Uint32()
  external int entryCount;
}

final class TlbSyltTrackList extends Struct {
  external Pointer<TlbSyltTrack> tracks;

  @Uint32()
  external int trackCount;
}

final class TlbSyltFilter extends Struct {
  external Pointer<Utf8> language;
  external Pointer<Utf8> description;

  @Int32()
  external int type;
}

final class TlbTextIssue extends Struct {
  @Int32()
  external int source;
  external Pointer<Utf8> fieldPath;
  external Pointer<Utf8> frameId;
  external Pointer<Utf8> language;
  external Pointer<Utf8> description;
  external Pointer<Uint8> rawBytes;

  @Uint32()
  external int rawBytesLength;

  external Pointer<Utf8> baselineDecoded;
}

final class TlbTextIssueList extends Struct {
  external Pointer<TlbTextIssue> issues;

  @Uint32()
  external int issueCount;
}

typedef _OpenSessionNative =
    Int32 Function(
      Pointer<Uint8>,
      Uint32,
      Pointer<Utf8>,
      Pointer<Pointer<TlbSession>>,
    );
typedef _OpenSession =
    int Function(
      Pointer<Uint8>,
      int,
      Pointer<Utf8>,
      Pointer<Pointer<TlbSession>>,
    );

typedef _OpenSessionFromPathNative =
    Int32 Function(Pointer<Utf8>, Pointer<Pointer<TlbSession>>);
typedef _OpenSessionFromPath =
    int Function(Pointer<Utf8>, Pointer<Pointer<TlbSession>>);

typedef _OpenSessionFromFdNative =
    Int32 Function(Int32, Pointer<Utf8>, Pointer<Pointer<TlbSession>>);
typedef _OpenSessionFromFd =
    int Function(int, Pointer<Utf8>, Pointer<Pointer<TlbSession>>);

typedef _CloseSessionNative = Int32 Function(Pointer<Pointer<TlbSession>>);
typedef _CloseSession = int Function(Pointer<Pointer<TlbSession>>);

typedef _FinalizeSessionNative = Void Function(Pointer<Void>);

typedef _ExportBytesNative =
    Int32 Function(
      Pointer<TlbSession>,
      Pointer<Pointer<Uint8>>,
      Pointer<Uint32>,
    );
typedef _ExportBytes =
    int Function(Pointer<TlbSession>, Pointer<Pointer<Uint8>>, Pointer<Uint32>);

typedef _ReadBasicTagsNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbBasicTags>);
typedef _ReadBasicTags =
    int Function(Pointer<TlbSession>, Pointer<TlbBasicTags>);

typedef _WriteBasicTagsNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbBasicTags>, Uint8);
typedef _WriteBasicTags =
    int Function(Pointer<TlbSession>, Pointer<TlbBasicTags>, int);

typedef _ReadAudioPropertiesNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbAudioProperties>);
typedef _ReadAudioProperties =
    int Function(Pointer<TlbSession>, Pointer<TlbAudioProperties>);

typedef _ProbeCapabilitiesNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbSessionCapabilities>);
typedef _ProbeCapabilities =
    int Function(Pointer<TlbSession>, Pointer<TlbSessionCapabilities>);

typedef _ReadPropertyMapNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbPropertyMap>);
typedef _ReadPropertyMap =
    int Function(Pointer<TlbSession>, Pointer<TlbPropertyMap>);

typedef _WritePropertyMapNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbPropertyMap>);
typedef _WritePropertyMap =
    int Function(Pointer<TlbSession>, Pointer<TlbPropertyMap>);

typedef _ReadPicturesNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbPictureList>);
typedef _ReadPictures =
    int Function(Pointer<TlbSession>, Pointer<TlbPictureList>);

typedef _WritePicturesNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbPictureList>, Uint8);
typedef _WritePictures =
    int Function(Pointer<TlbSession>, Pointer<TlbPictureList>, int);

typedef _WritePictureFilesNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbPictureFileList>, Uint8);
typedef _WritePictureFiles =
    int Function(Pointer<TlbSession>, Pointer<TlbPictureFileList>, int);

typedef _ReadLyricsNative =
    Int32 Function(
      Pointer<TlbSession>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef _ReadLyrics =
    int Function(
      Pointer<TlbSession>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );

typedef _WriteLyricsNative =
    Int32 Function(
      Pointer<TlbSession>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Uint8,
    );
typedef _WriteLyrics =
    int Function(
      Pointer<TlbSession>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
    );

typedef _ClearLyricsNative =
    Int32 Function(Pointer<TlbSession>, Pointer<Utf8>, Pointer<Utf8>, Uint8);
typedef _ClearLyrics =
    int Function(Pointer<TlbSession>, Pointer<Utf8>, Pointer<Utf8>, int);

typedef _SaveWithVersionNative = Int32 Function(Pointer<TlbSession>, Uint8);
typedef _SaveWithVersion = int Function(Pointer<TlbSession>, int);

typedef _ReadSyltNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbSyltTrackList>);
typedef _ReadSylt =
    int Function(Pointer<TlbSession>, Pointer<TlbSyltTrackList>);

typedef _WriteSyltNative =
    Int32 Function(
      Pointer<TlbSession>,
      Pointer<TlbSyltTrack>,
      Uint32,
      Int32,
      Uint8,
    );
typedef _WriteSylt =
    int Function(Pointer<TlbSession>, Pointer<TlbSyltTrack>, int, int, int);

typedef _ClearSyltNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbSyltFilter>, Uint8);
typedef _ClearSylt =
    int Function(Pointer<TlbSession>, Pointer<TlbSyltFilter>, int);

typedef _ScanTextIssuesNative =
    Int32 Function(Pointer<TlbSession>, Pointer<TlbTextIssueList>);
typedef _ScanTextIssues =
    int Function(Pointer<TlbSession>, Pointer<TlbTextIssueList>);

typedef _ApiVersionNative = Uint32 Function();
typedef _ApiVersion = int Function();

typedef _StatusMessageNative = Pointer<Utf8> Function(Int32);
typedef _StatusMessage = Pointer<Utf8> Function(int);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeString = void Function(Pointer<Utf8>);

typedef _FreeBytesNative = Void Function(Pointer<Uint8>);
typedef _FreeBytes = void Function(Pointer<Uint8>);

typedef _FreeBasicTagsNative = Void Function(Pointer<TlbBasicTags>);
typedef _FreeBasicTags = void Function(Pointer<TlbBasicTags>);

typedef _FreePropertyMapNative = Void Function(Pointer<TlbPropertyMap>);
typedef _FreePropertyMap = void Function(Pointer<TlbPropertyMap>);

typedef _FreePictureListNative = Void Function(Pointer<TlbPictureList>);
typedef _FreePictureList = void Function(Pointer<TlbPictureList>);

typedef _FreeSyltListNative = Void Function(Pointer<TlbSyltTrackList>);
typedef _FreeSyltList = void Function(Pointer<TlbSyltTrackList>);

typedef _FreeTextIssueListNative = Void Function(Pointer<TlbTextIssueList>);
typedef _FreeTextIssueList = void Function(Pointer<TlbTextIssueList>);

@Native<_OpenSessionNative>(symbol: 'tlb_session_open_from_bytes')
external int _nativeOpenSessionFromBytes(
  Pointer<Uint8> bytes,
  int length,
  Pointer<Utf8> nameHint,
  Pointer<Pointer<TlbSession>> session,
);

@Native<_OpenSessionFromPathNative>(symbol: 'tlb_session_open_from_path')
external int _nativeOpenSessionFromPath(
  Pointer<Utf8> path,
  Pointer<Pointer<TlbSession>> session,
);

@Native<_OpenSessionFromFdNative>(symbol: 'tlb_session_open_from_fd')
external int _nativeOpenSessionFromFd(
  int fileDescriptor,
  Pointer<Utf8> nameHint,
  Pointer<Pointer<TlbSession>> session,
);

@Native<_CloseSessionNative>(symbol: 'tlb_session_close')
external int _nativeCloseSession(Pointer<Pointer<TlbSession>> session);

@Native<_FinalizeSessionNative>(symbol: 'tlb_session_finalize')
external void _nativeFinalizeSession(Pointer<Void> session);

@Native<_ExportBytesNative>(symbol: 'tlb_session_export_bytes')
external int _nativeExportSessionBytes(
  Pointer<TlbSession> session,
  Pointer<Pointer<Uint8>> bytes,
  Pointer<Uint32> length,
);

@Native<_ReadBasicTagsNative>(symbol: 'tlb_session_read_basic_tags')
external int _nativeReadBasicTags(
  Pointer<TlbSession> session,
  Pointer<TlbBasicTags> tags,
);

@Native<_WriteBasicTagsNative>(symbol: 'tlb_session_write_basic_tags')
external int _nativeWriteBasicTags(
  Pointer<TlbSession> session,
  Pointer<TlbBasicTags> tags,
  int id3v2Version,
);

@Native<_ReadAudioPropertiesNative>(symbol: 'tlb_session_read_audio_properties')
external int _nativeReadAudioProperties(
  Pointer<TlbSession> session,
  Pointer<TlbAudioProperties> properties,
);

@Native<_ProbeCapabilitiesNative>(symbol: 'tlb_session_probe_capabilities')
external int _nativeProbeCapabilities(
  Pointer<TlbSession> session,
  Pointer<TlbSessionCapabilities> capabilities,
);

@Native<_ReadPropertyMapNative>(symbol: 'tlb_session_read_property_map')
external int _nativeReadPropertyMap(
  Pointer<TlbSession> session,
  Pointer<TlbPropertyMap> map,
);

@Native<_WritePropertyMapNative>(symbol: 'tlb_session_write_property_map')
external int _nativeWritePropertyMap(
  Pointer<TlbSession> session,
  Pointer<TlbPropertyMap> map,
);

@Native<_ReadPicturesNative>(symbol: 'tlb_session_read_pictures')
external int _nativeReadPictures(
  Pointer<TlbSession> session,
  Pointer<TlbPictureList> list,
);

@Native<_WritePicturesNative>(symbol: 'tlb_session_write_pictures')
external int _nativeWritePictures(
  Pointer<TlbSession> session,
  Pointer<TlbPictureList> list,
  int clearExisting,
);

@Native<_WritePictureFilesNative>(symbol: 'tlb_session_write_picture_files')
external int _nativeWritePictureFiles(
  Pointer<TlbSession> session,
  Pointer<TlbPictureFileList> list,
  int clearExisting,
);

@Native<_ReadLyricsNative>(symbol: 'tlb_session_read_lyrics')
external int _nativeReadLyrics(
  Pointer<TlbSession> session,
  Pointer<Utf8> language,
  Pointer<Utf8> description,
  Pointer<Pointer<Utf8>> textOut,
);

@Native<_WriteLyricsNative>(symbol: 'tlb_session_write_lyrics')
external int _nativeWriteLyrics(
  Pointer<TlbSession> session,
  Pointer<Utf8> text,
  Pointer<Utf8> language,
  Pointer<Utf8> description,
  int id3v2Version,
);

@Native<_ClearLyricsNative>(symbol: 'tlb_session_clear_lyrics')
external int _nativeClearLyrics(
  Pointer<TlbSession> session,
  Pointer<Utf8> language,
  Pointer<Utf8> description,
  int id3v2Version,
);

@Native<_SaveWithVersionNative>(
  symbol: 'tlb_session_mp3_save_with_id3v2_version',
)
external int _nativeSaveWithVersion(
  Pointer<TlbSession> session,
  int id3v2Version,
);

@Native<_ReadSyltNative>(symbol: 'tlb_session_mp3_sylt_read')
external int _nativeReadSylt(
  Pointer<TlbSession> session,
  Pointer<TlbSyltTrackList> list,
);

@Native<_WriteSyltNative>(symbol: 'tlb_session_mp3_sylt_write')
external int _nativeWriteSylt(
  Pointer<TlbSession> session,
  Pointer<TlbSyltTrack> tracks,
  int trackCount,
  int mergeMode,
  int id3v2Version,
);

@Native<_ClearSyltNative>(symbol: 'tlb_session_mp3_sylt_clear')
external int _nativeClearSylt(
  Pointer<TlbSession> session,
  Pointer<TlbSyltFilter> filter,
  int id3v2Version,
);

@Native<_ScanTextIssuesNative>(symbol: 'tlb_session_text_issues_scan')
external int _nativeScanTextIssues(
  Pointer<TlbSession> session,
  Pointer<TlbTextIssueList> list,
);

@Native<_ApiVersionNative>(symbol: 'tlb_api_version')
external int _nativeApiVersion();

@Native<_StatusMessageNative>(symbol: 'tlb_status_message')
external Pointer<Utf8> _nativeStatusMessage(int status);

@Native<_FreeStringNative>(symbol: 'tlb_free_string')
external void _nativeFreeString(Pointer<Utf8> value);

@Native<_FreeBytesNative>(symbol: 'tlb_free_bytes')
external void _nativeFreeBytes(Pointer<Uint8> bytes);

@Native<_FreeBasicTagsNative>(symbol: 'tlb_free_basic_tags')
external void _nativeFreeBasicTags(Pointer<TlbBasicTags> tags);

@Native<_FreePropertyMapNative>(symbol: 'tlb_free_property_map')
external void _nativeFreePropertyMap(Pointer<TlbPropertyMap> map);

@Native<_FreePictureListNative>(symbol: 'tlb_free_picture_list')
external void _nativeFreePictureList(Pointer<TlbPictureList> list);

@Native<_FreeSyltListNative>(symbol: 'tlb_free_sylt_track_list')
external void _nativeFreeSyltTrackList(Pointer<TlbSyltTrackList> list);

@Native<_FreeTextIssueListNative>(symbol: 'tlb_free_text_issue_list')
external void _nativeFreeTextIssueList(Pointer<TlbTextIssueList> list);

final class TaglibBridgeFfi {
  static const int expectedApiVersion = 4;

  TaglibBridgeFfi(this.library)
    : apiVersion = library.lookupFunction<_ApiVersionNative, _ApiVersion>(
        'tlb_api_version',
      ),
      openSessionFromBytes = library
          .lookupFunction<_OpenSessionNative, _OpenSession>(
            'tlb_session_open_from_bytes',
          ),
      openSessionFromPath = library
          .lookupFunction<_OpenSessionFromPathNative, _OpenSessionFromPath>(
            'tlb_session_open_from_path',
          ),
      openSessionFromFd = library
          .lookupFunction<_OpenSessionFromFdNative, _OpenSessionFromFd>(
            'tlb_session_open_from_fd',
          ),
      closeSession = library.lookupFunction<_CloseSessionNative, _CloseSession>(
        'tlb_session_close',
      ),
      finalizeSession = library.lookup<NativeFunction<_FinalizeSessionNative>>(
        'tlb_session_finalize',
      ),
      exportSessionBytes = library
          .lookupFunction<_ExportBytesNative, _ExportBytes>(
            'tlb_session_export_bytes',
          ),
      readBasicTags = library
          .lookupFunction<_ReadBasicTagsNative, _ReadBasicTags>(
            'tlb_session_read_basic_tags',
          ),
      writeBasicTags = library
          .lookupFunction<_WriteBasicTagsNative, _WriteBasicTags>(
            'tlb_session_write_basic_tags',
          ),
      readAudioProperties = library
          .lookupFunction<_ReadAudioPropertiesNative, _ReadAudioProperties>(
            'tlb_session_read_audio_properties',
          ),
      probeCapabilities = library
          .lookupFunction<_ProbeCapabilitiesNative, _ProbeCapabilities>(
            'tlb_session_probe_capabilities',
          ),
      readPropertyMap = library
          .lookupFunction<_ReadPropertyMapNative, _ReadPropertyMap>(
            'tlb_session_read_property_map',
          ),
      writePropertyMap = library
          .lookupFunction<_WritePropertyMapNative, _WritePropertyMap>(
            'tlb_session_write_property_map',
          ),
      readPictures = library.lookupFunction<_ReadPicturesNative, _ReadPictures>(
        'tlb_session_read_pictures',
      ),
      writePictures = library
          .lookupFunction<_WritePicturesNative, _WritePictures>(
            'tlb_session_write_pictures',
          ),
      writePictureFiles = library
          .lookupFunction<_WritePictureFilesNative, _WritePictureFiles>(
            'tlb_session_write_picture_files',
          ),
      readLyrics = library.lookupFunction<_ReadLyricsNative, _ReadLyrics>(
        'tlb_session_read_lyrics',
      ),
      writeLyrics = library.lookupFunction<_WriteLyricsNative, _WriteLyrics>(
        'tlb_session_write_lyrics',
      ),
      clearLyrics = library.lookupFunction<_ClearLyricsNative, _ClearLyrics>(
        'tlb_session_clear_lyrics',
      ),
      saveWithId3v2Version = library
          .lookupFunction<_SaveWithVersionNative, _SaveWithVersion>(
            'tlb_session_mp3_save_with_id3v2_version',
          ),
      readSylt = library.lookupFunction<_ReadSyltNative, _ReadSylt>(
        'tlb_session_mp3_sylt_read',
      ),
      writeSylt = library.lookupFunction<_WriteSyltNative, _WriteSylt>(
        'tlb_session_mp3_sylt_write',
      ),
      clearSylt = library.lookupFunction<_ClearSyltNative, _ClearSylt>(
        'tlb_session_mp3_sylt_clear',
      ),
      scanTextIssues = library
          .lookupFunction<_ScanTextIssuesNative, _ScanTextIssues>(
            'tlb_session_text_issues_scan',
          ),
      statusMessage = library
          .lookupFunction<_StatusMessageNative, _StatusMessage>(
            'tlb_status_message',
          ),
      freeString = library.lookupFunction<_FreeStringNative, _FreeString>(
        'tlb_free_string',
      ),
      freeBytes = library.lookupFunction<_FreeBytesNative, _FreeBytes>(
        'tlb_free_bytes',
      ),
      freeBasicTags = library
          .lookupFunction<_FreeBasicTagsNative, _FreeBasicTags>(
            'tlb_free_basic_tags',
          ),
      freePropertyMap = library
          .lookupFunction<_FreePropertyMapNative, _FreePropertyMap>(
            'tlb_free_property_map',
          ),
      freePictureList = library
          .lookupFunction<_FreePictureListNative, _FreePictureList>(
            'tlb_free_picture_list',
          ),
      freeSyltTrackList = library
          .lookupFunction<_FreeSyltListNative, _FreeSyltList>(
            'tlb_free_sylt_track_list',
          ),
      freeTextIssueList = library
          .lookupFunction<_FreeTextIssueListNative, _FreeTextIssueList>(
            'tlb_free_text_issue_list',
          );

  TaglibBridgeFfi.nativeAsset()
    : library = DynamicLibrary.process(),
      apiVersion = _nativeApiVersion,
      openSessionFromBytes = _nativeOpenSessionFromBytes,
      openSessionFromPath = _nativeOpenSessionFromPath,
      openSessionFromFd = _nativeOpenSessionFromFd,
      closeSession = _nativeCloseSession,
      finalizeSession =
          Native.addressOf<NativeFunction<_FinalizeSessionNative>>(
            _nativeFinalizeSession,
          ),
      exportSessionBytes = _nativeExportSessionBytes,
      readBasicTags = _nativeReadBasicTags,
      writeBasicTags = _nativeWriteBasicTags,
      readAudioProperties = _nativeReadAudioProperties,
      probeCapabilities = _nativeProbeCapabilities,
      readPropertyMap = _nativeReadPropertyMap,
      writePropertyMap = _nativeWritePropertyMap,
      readPictures = _nativeReadPictures,
      writePictures = _nativeWritePictures,
      writePictureFiles = _nativeWritePictureFiles,
      readLyrics = _nativeReadLyrics,
      writeLyrics = _nativeWriteLyrics,
      clearLyrics = _nativeClearLyrics,
      saveWithId3v2Version = _nativeSaveWithVersion,
      readSylt = _nativeReadSylt,
      writeSylt = _nativeWriteSylt,
      clearSylt = _nativeClearSylt,
      scanTextIssues = _nativeScanTextIssues,
      statusMessage = _nativeStatusMessage,
      freeString = _nativeFreeString,
      freeBytes = _nativeFreeBytes,
      freeBasicTags = _nativeFreeBasicTags,
      freePropertyMap = _nativeFreePropertyMap,
      freePictureList = _nativeFreePictureList,
      freeSyltTrackList = _nativeFreeSyltTrackList,
      freeTextIssueList = _nativeFreeTextIssueList;

  final DynamicLibrary library;

  final _ApiVersion apiVersion;
  final _OpenSession openSessionFromBytes;
  final _OpenSessionFromPath openSessionFromPath;
  final _OpenSessionFromFd openSessionFromFd;
  final _CloseSession closeSession;
  final Pointer<NativeFunction<_FinalizeSessionNative>> finalizeSession;
  final _ExportBytes exportSessionBytes;

  final _ReadBasicTags readBasicTags;
  final _WriteBasicTags writeBasicTags;
  final _ReadAudioProperties readAudioProperties;
  final _ProbeCapabilities probeCapabilities;

  final _ReadPropertyMap readPropertyMap;
  final _WritePropertyMap writePropertyMap;

  final _ReadPictures readPictures;
  final _WritePictures writePictures;
  final _WritePictureFiles writePictureFiles;

  final _ReadLyrics readLyrics;
  final _WriteLyrics writeLyrics;
  final _ClearLyrics clearLyrics;

  final _SaveWithVersion saveWithId3v2Version;

  final _ReadSylt readSylt;
  final _WriteSylt writeSylt;
  final _ClearSylt clearSylt;

  final _ScanTextIssues scanTextIssues;

  final _StatusMessage statusMessage;
  final _FreeString freeString;
  final _FreeBytes freeBytes;
  final _FreeBasicTags freeBasicTags;
  final _FreePropertyMap freePropertyMap;
  final _FreePictureList freePictureList;
  final _FreeSyltList freeSyltTrackList;
  final _FreeTextIssueList freeTextIssueList;
  void validateBridge({required String source}) {
    final actualVersion = apiVersion();
    if (actualVersion != expectedApiVersion) {
      throw StateError(
        'taglib_bridge ABI version mismatch from $source: '
        'expected $expectedApiVersion, actual $actualVersion.',
      );
    }
  }
}
