// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

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
import 'package:web/web.dart' as web;

import 'wasm_runtime_config.dart';

const String _bridgeGlobalKey = '__taglibBridge';
const String _moduleFactoryGlobalKey = 'TaglibBridgeModule';
const String _bridgeInitializerGlobalKey = 'initTaglibBridge';
const String _moduleScriptName = 'taglib_bridge.js';
const String _bridgeScriptName = 'taglib_bridge_web.js';

final Map<String, Future<void>> _scriptLoads = <String, Future<void>>{};
Future<void>? _bridgeInitialization;
String? _bridgeInitializationBaseUrl;

Never _rethrowBridgeError(Object error, StackTrace stackTrace) {
  final status = _readStatusFromBridgeError(error);
  if (status != null) {
    throw TaglibException(status, _readMessageFromBridgeError(error));
  }
  Error.throwWithStackTrace(error, stackTrace);
}

int? _readStatusFromBridgeError(Object error) {
  try {
    final jsError = _tryAsJsObject(error);
    if (jsError == null) return null;
    final value = jsError.getProperty<JSAny?>('status'.toJS)?.dartify();
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
  } on Object {
    // Preserve the original stack for errors that do not come from the bridge.
  }
  return null;
}

String _readMessageFromBridgeError(Object error) {
  try {
    final jsError = _tryAsJsObject(error);
    if (jsError == null) return error.toString();
    final value = jsError.getProperty<JSAny?>('message'.toJS)?.dartify();
    if (value is String && value.isNotEmpty) {
      return value;
    }
  } on Object {
    // Fall back to Dart's default string conversion.
  }
  return error.toString();
}

JSObject? _tryAsJsObject(Object? value) {
  if (value == null) return null;
  try {
    final jsValue = value as JSAny;
    if (!jsValue.isA<JSObject>()) return null;
    return jsValue as JSObject;
  } on Object {
    return null;
  }
}

JSAny? _toJsAny(Object? value) {
  if (value == null) return null;
  if (value is String) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  if (value is num) return value.toDouble().toJS;
  if (value is Uint8List) return value.toJS;
  if (value is Map || value is Iterable) return value.jsify();
  try {
    final jsValue = value as JSAny;
    if (jsValue.isA<JSObject>() || jsValue.isA<JSFunction>()) {
      return jsValue;
    }
  } on Object {
    // Keep ordinary Dart objects on jsify so dart2js does not pass Map/List
    // instances directly to JavaScript.
  }
  return value.jsify();
}

/// Initializes the packaged TagLib WebAssembly runtime in a browser.
///
/// [assetBaseUrl] must identify a same-origin directory containing
/// `taglib_bridge.js`, `taglib_bridge.wasm`, and `taglib_bridge_web.js`.
/// Concurrent calls using the same URL share one initialization. A failed
/// initialization can be retried.
Future<void> initializeTaglibWasmBridge({
  String assetBaseUrl = taglibWasmDefaultAssetBaseUrl,
  Object? moduleOptions,
}) {
  if (hasTaglibWasmBridge()) {
    return Future<void>.value();
  }

  final normalizedBaseUrl = _normalizeAssetBaseUrl(assetBaseUrl);
  final inFlight = _bridgeInitialization;
  if (inFlight != null) {
    if (_bridgeInitializationBaseUrl != normalizedBaseUrl) {
      return Future<void>.error(
        StateError(
          'The TagLib WebAssembly bridge is already initializing from '
          '$_bridgeInitializationBaseUrl.',
        ),
      );
    }
    return inFlight;
  }

  final initialization = _initializeTaglibWasmBridge(
    assetBaseUrl: normalizedBaseUrl,
    moduleOptions: moduleOptions,
  );
  _bridgeInitialization = initialization;
  _bridgeInitializationBaseUrl = normalizedBaseUrl;
  initialization.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {
      if (identical(_bridgeInitialization, initialization)) {
        _bridgeInitialization = null;
        _bridgeInitializationBaseUrl = null;
      }
    },
  );
  return initialization;
}

Future<void> _initializeTaglibWasmBridge({
  required String assetBaseUrl,
  required Object? moduleOptions,
}) async {
  if (globalContext.getProperty<JSAny?>(_moduleFactoryGlobalKey.toJS) == null) {
    await _loadBrowserScript(_assetUrl(assetBaseUrl, _moduleScriptName));
  }
  final moduleFactory = globalContext.getProperty<JSAny?>(
    _moduleFactoryGlobalKey.toJS,
  );
  if (moduleFactory == null || !moduleFactory.isA<JSFunction>()) {
    throw StateError(
      '$_moduleFactoryGlobalKey was not provided by $_moduleScriptName.',
    );
  }

  if (globalContext.getProperty<JSAny?>(_bridgeInitializerGlobalKey.toJS) ==
      null) {
    await _loadBrowserScript(_assetUrl(assetBaseUrl, _bridgeScriptName));
  }
  final initFn = globalContext.getProperty<JSAny?>(
    _bridgeInitializerGlobalKey.toJS,
  );
  if (initFn == null || !initFn.isA<JSFunction>()) {
    throw StateError(
      '$_bridgeInitializerGlobalKey was not provided by $_bridgeScriptName.',
    );
  }

  final promise = globalContext.callMethodVarArgs<JSPromise<JSAny?>>(
    _bridgeInitializerGlobalKey.toJS,
    <JSAny?>[moduleFactory, _toJsAny(moduleOptions)],
  );
  final resolved = await promise.toDart;
  if (resolved == null || !resolved.isA<JSObject>()) {
    throw StateError('$_bridgeInitializerGlobalKey resolved to a non-object.');
  }
  globalContext.setProperty(_bridgeGlobalKey.toJS, resolved);
}

String _normalizeAssetBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, 'assetBaseUrl', 'Must not be empty.');
  }
  return trimmed.endsWith('/') ? trimmed : '$trimmed/';
}

String _assetUrl(String baseUrl, String fileName) =>
    Uri.parse(baseUrl).resolve(fileName).toString();

Future<void> _loadBrowserScript(String source) {
  final existing = _scriptLoads[source];
  if (existing != null) {
    return existing;
  }

  final future = _appendBrowserScript(source);
  _scriptLoads[source] = future;
  future.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {
      if (identical(_scriptLoads[source], future)) {
        _scriptLoads.remove(source);
      }
    },
  );
  return future;
}

Future<void> _appendBrowserScript(String source) async {
  final parent = web.document.head ?? web.document.body;
  if (parent == null) {
    throw StateError('The document cannot accept script elements yet.');
  }

  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..type = 'text/javascript'
    ..src = source
    ..async = false;
  late final StreamSubscription<web.Event> loadSubscription;
  late final StreamSubscription<web.Event> errorSubscription;
  loadSubscription = script.onLoad.listen((_) async {
    await errorSubscription.cancel();
    await loadSubscription.cancel();
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  errorSubscription = script.onError.listen((_) async {
    await loadSubscription.cancel();
    await errorSubscription.cancel();
    script.remove();
    if (!completer.isCompleted) {
      completer.completeError(StateError('Failed to load script: $source'));
    }
  });

  parent.append(script);
  return completer.future;
}

/// Whether the TagLib WebAssembly bridge has completed initialization.
bool hasTaglibWasmBridge() {
  final bridge = globalContext.getProperty<JSAny?>(_bridgeGlobalKey.toJS);
  return bridge != null;
}

/// TagLib backend that delegates operations to the initialized WebAssembly
/// bridge.
final class WasmTaglibBackend implements TaglibBackend {
  /// Creates a backend using [bridge], or the globally initialized bridge when
  /// [bridge] is omitted.
  WasmTaglibBackend({Object? bridge}) : _bridge = _resolveBridge(bridge);

  final JSObject _bridge;

  static JSObject _resolveBridge(Object? bridge) {
    final jsBridge = bridge == null
        ? globalContext.getProperty<JSAny?>(_bridgeGlobalKey.toJS)
        : _toJsAny(bridge);
    if (jsBridge == null) {
      throw UnsupportedError(
        'No wasm bridge found on globalThis.$_bridgeGlobalKey. '
        'Call initializeTaglibWasmBridge() before creating the backend.',
      );
    }
    if (!jsBridge.isA<JSObject>()) {
      throw ArgumentError.value(
        bridge,
        'bridge',
        'Expected a JavaScript object',
      );
    }
    return jsBridge as JSObject;
  }

  @override
  TaglibSessionBackend openSession(Uint8List bytes, {String? nameHint}) {
    final fn = _bridge.getProperty<JSAny?>('openSessionFromBytes'.toJS);
    if (fn == null) {
      throw UnsupportedError(
        'Wasm bridge method not found: openSessionFromBytes',
      );
    }
    JSAny? jsSession;
    try {
      jsSession = _bridge.callMethodVarArgs<JSAny?>(
        'openSessionFromBytes'.toJS,
        <JSAny?>[bytes.toJS, nameHint?.toJS],
      );
    } on Object catch (error, stackTrace) {
      _rethrowBridgeError(error, stackTrace);
    }
    final session = jsSession;
    if (session == null || !session.isA<JSObject>()) {
      throw StateError('Wasm bridge returned a non-object session.');
    }
    return _WasmTaglibSession(session as JSObject);
  }
}

final class _WasmTaglibSession
    implements TaglibSessionBackend, TaglibSessionCapabilityProbeBackend {
  _WasmTaglibSession(this._session);

  final JSObject _session;
  bool _closed = false;

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Taglib session is already closed.');
    }
  }

  Object? _call(String method, List<Object?> args) {
    _ensureOpen();
    final fn = _session.getProperty<JSAny?>(method.toJS);
    if (fn == null) {
      throw UnsupportedError('Wasm session method not found: $method');
    }
    final jsArgs = args.map(_toJsAny).toList(growable: false);
    try {
      return _session.callMethodVarArgs<JSAny?>(method.toJS, jsArgs)?.dartify();
    } on Object catch (error, stackTrace) {
      _rethrowBridgeError(error, stackTrace);
    }
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return fallback;
  }

  static String? _asNullableString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  static List<dynamic> _list(Object? value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  static Uint8List _asBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) {
      return Uint8List.fromList(value.map((item) => _asInt(item)).toList());
    }
    return Uint8List(0);
  }

  @override
  BasicTags readBasicTags() {
    final raw = _map(_call('readBasicTags', const <Object?>[]));
    return BasicTags(
      title: _asNullableString(raw['title']),
      artist: _asNullableString(raw['artist']),
      album: _asNullableString(raw['album']),
      comment: _asNullableString(raw['comment']),
      genre: _asNullableString(raw['genre']),
      lyrics: _asNullableString(raw['lyrics']),
      year: _asInt(raw['year']),
      track: _asInt(raw['track']),
    );
  }

  @override
  void writeBasicTags(BasicTags tags, Id3v2Version id3v2Version) {
    _call('writeBasicTags', <Object?>[
      <String, Object?>{
        'title': tags.title,
        'artist': tags.artist,
        'album': tags.album,
        'comment': tags.comment,
        'genre': tags.genre,
        'lyrics': tags.lyrics,
        'year': tags.year,
        'track': tags.track,
      },
      id3v2Version.nativeValue,
    ]);
  }

  @override
  AudioProperties? readAudioProperties() {
    final row = _map(_call('readAudioProperties', const <Object?>[]));
    if (row.isEmpty) return null;
    return AudioProperties(
      lengthSeconds: _asInt(row['lengthSeconds']),
      bitrateKbps: _asInt(row['bitrateKbps']),
      sampleRate: _asInt(row['sampleRate']),
      channels: _asInt(row['channels']),
    );
  }

  @override
  SessionCapabilities probeCapabilities() {
    final raw = _map(_call('probeCapabilities', const <Object?>[]));
    return SessionCapabilities(
      plainLyricsWritable: _asBool(raw['plainLyricsWritable']),
      syncedLyricsWritable: _asBool(raw['syncedLyricsWritable']),
      mp3Id3SaveSupported: _asBool(raw['mp3Id3SaveSupported']),
      uslt: _asBool(raw['uslt']),
      lyrics: _asBool(raw['lyrics']),
      mp4Lyr: _asBool(raw['mp4Lyr']),
      wmLyrics: _asBool(raw['wmLyrics']),
      hintBased: _asBool(raw['hintBased']),
    );
  }

  @override
  PropertyMap readPropertyMap() {
    final raw = _map(_call('readPropertyMap', const <Object?>[]));
    final rows = _list(raw['items']);
    return PropertyMap(
      items: <PropertyItem>[
        for (final row in rows)
          () {
            final item = _map(row);
            return PropertyItem(
              key: _asNullableString(item['key']) ?? '',
              values: <String>[
                for (final value in _list(item['values']))
                  _asNullableString(value) ?? '',
              ],
            );
          }(),
      ],
    );
  }

  @override
  void writePropertyMap(PropertyMap map) {
    _call('writePropertyMap', <Object?>[
      <String, Object?>{
        'items': <Map<String, Object?>>[
          for (final item in map.items)
            <String, Object?>{'key': item.key, 'values': item.values},
        ],
      },
    ]);
  }

  @override
  List<PictureItem> readPictures() {
    final raw = _map(_call('readPictures', const <Object?>[]));
    final rows = _list(raw['items']);
    return <PictureItem>[
      for (final row in rows)
        () {
          final item = _map(row);
          return PictureItem(
            mimeType: _asNullableString(item['mimeType']),
            description: _asNullableString(item['description']),
            pictureType: _asNullableString(item['pictureType']),
            data: _asBytes(item['data']),
          );
        }(),
    ];
  }

  @override
  void writePictures(
    List<PictureItem> pictures, {
    required bool clearExisting,
  }) {
    _call('writePictures', <Object?>[
      <Map<String, Object?>>[
        for (final item in pictures)
          <String, Object?>{
            'mimeType': item.mimeType,
            'description': item.description,
            'pictureType': item.pictureType,
            'data': item.data,
          },
      ],
      clearExisting,
    ]);
  }

  @override
  void writePicturesFromFiles(
    List<PictureFileItem> pictures, {
    required bool clearExisting,
  }) {
    throw UnsupportedError(
      'The Web backend cannot write cover art from local file paths.',
    );
  }

  @override
  String? readLyrics({String? language, String? description}) {
    final raw = _call('readLyrics', <Object?>[
      <String, Object?>{'language': language, 'description': description},
    ]);
    return _asNullableString(raw);
  }

  @override
  void writeLyrics(
    String text, {
    required String language,
    required String description,
    required Id3v2Version id3v2Version,
  }) {
    _call('writeLyrics', <Object?>[
      text,
      <String, Object?>{
        'language': language,
        'description': description,
        'id3v2Version': id3v2Version.nativeValue,
      },
    ]);
  }

  @override
  void clearLyrics({
    String? language,
    String? description,
    required Id3v2Version id3v2Version,
  }) {
    _call('clearLyrics', <Object?>[
      <String, Object?>{
        'language': language,
        'description': description,
        'id3v2Version': id3v2Version.nativeValue,
      },
    ]);
  }

  @override
  void saveMp3WithId3v2Version(Id3v2Version version) {
    _call('saveMp3WithId3v2Version', <Object?>[version.nativeValue]);
  }

  @override
  List<SyncedLyricsTrack> readSyncedLyrics() {
    final rows = _list(_call('readSyncedLyrics', const <Object?>[]));
    return <SyncedLyricsTrack>[
      for (final row in rows)
        () {
          final item = _map(row);
          final entries = _list(item['entries']);
          return SyncedLyricsTrack(
            language: _asNullableString(item['language']) ?? 'eng',
            description: _asNullableString(item['description']) ?? '',
            type: SyncedLyricsType.fromNative(_asInt(item['type'])),
            timestampFormat: SyncedLyricsTimestampFormat.fromNative(
              _asInt(item['timestampFormat']),
            ),
            entries: <SyncedLyricsEntry>[
              for (final entry in entries)
                () {
                  final e = _map(entry);
                  return SyncedLyricsEntry(
                    time: _asInt(e['time']),
                    text: _asNullableString(e['text']) ?? '',
                  );
                }(),
            ],
          );
        }(),
    ];
  }

  @override
  void writeSyncedLyrics(
    List<SyncedLyricsTrack> tracks, {
    required SyltMergeMode mergeMode,
    required Id3v2Version id3v2Version,
  }) {
    _call('writeSyncedLyrics', <Object?>[
      <Map<String, Object?>>[
        for (final track in tracks)
          <String, Object?>{
            'language': track.language,
            'description': track.description,
            'type': track.type.nativeValue,
            'timestampFormat': track.timestampFormat.nativeValue,
            'entries': <Map<String, Object?>>[
              for (final entry in track.entries)
                <String, Object?>{'time': entry.time, 'text': entry.text},
            ],
          },
      ],
      <String, Object?>{
        'mergeMode': mergeMode.nativeValue,
        'id3v2Version': id3v2Version.nativeValue,
      },
    ]);
  }

  @override
  void clearSyncedLyrics({
    SyncedLyricsFilter? filter,
    required Id3v2Version id3v2Version,
  }) {
    _call('clearSyncedLyrics', <Object?>[
      <String, Object?>{
        'filter': filter == null
            ? null
            : <String, Object?>{
                'language': filter.language,
                'description': filter.description,
                'type': filter.type?.nativeValue,
              },
        'id3v2Version': id3v2Version.nativeValue,
      },
    ]);
  }

  @override
  List<TextIssue> scanTextIssues() {
    final rows = _list(_call('scanTextIssues', const <Object?>[]));
    return <TextIssue>[
      for (final row in rows)
        () {
          final item = _map(row);
          return TextIssue(
            source: TextIssueSource.fromNative(_asInt(item['source'])),
            fieldPath: _asNullableString(item['fieldPath']),
            frameId: _asNullableString(item['frameId']),
            language: _asNullableString(item['language']),
            description: _asNullableString(item['description']),
            rawBytes: _asBytes(item['rawBytes']),
            baselineDecoded: _asNullableString(item['baselineDecoded']),
          );
        }(),
    ];
  }

  @override
  Uint8List exportBytes() {
    final raw = _call('exportBytes', const <Object?>[]);
    return _asBytes(raw);
  }

  @override
  void close() {
    if (_closed) return;
    _call('close', const <Object?>[]);
    _closed = true;
  }
}
