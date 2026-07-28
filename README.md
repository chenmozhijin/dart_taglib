# dart_taglib

Cross-platform Dart bindings for [TagLib](https://taglib.org/), backed by
native FFI on desktop and mobile platforms and WebAssembly in browsers.

[English](README.md) | [简体中文](README_zh.md)

## Installation

```console
dart pub add dart_taglib
```

## Platform Support

| Platform | Backend | Requirements |
| --- | --- | --- |
| Windows | Native FFI | CMake and a C/C++ toolchain |
| Linux | Native FFI | CMake and a C/C++ toolchain |
| macOS | Native FFI | CMake and Xcode command-line tools |
| Android | Native FFI | Android NDK and CMake |
| iOS | Native FFI | macOS, Xcode, and CMake |
| Web | WebAssembly | Runtime initialization described below |

The native library is built automatically when the application is built.

## Web Setup

Call `initializeTaglibWasmBridge()` before creating `TaglibApi` on Web.

```dart
import 'package:dart_taglib/dart_taglib.dart';

Future<void> main() async {
  await initializeTaglibWasmBridge();
  final api = TaglibApi();
  // Start the application with api.
}
```

### Flutter Web

Flutter automatically bundles the JavaScript and WebAssembly runtime at the
default package asset URL. No copy command or `index.html` script tag is
required.

### Pure Dart Web

Install the packaged runtime from the application root before compiling or
serving the application:

```console
dart run dart_taglib:install_web_runtime
```

The default destination is
`web/assets/packages/dart_taglib/web_runtime`, which matches the URL used by
`initializeTaglibWasmBridge()`. A read-only check is suitable for application
builds and CI:

```console
dart run dart_taglib:install_web_runtime --check
```

For a custom same-origin location, use matching output and URL values:

```console
dart run dart_taglib:install_web_runtime --output web/vendor/dart_taglib
```

```dart
await initializeTaglibWasmBridge(assetBaseUrl: 'vendor/dart_taglib/');
```

## Usage

Most operations start with `TaglibApi`. Sessions retain native or WebAssembly
resources, so close them in a `finally` block.

### Reading Tags

```dart
import 'dart:io';

import 'package:dart_taglib/dart_taglib.dart';

final api = TaglibApi();
final bytes = File('my_song.mp3').readAsBytesSync();
final result = api.readTagsFromBytes(bytes);

print(result.tags.title);
print(result.tags.artist);
```

### Writing Tags, Pictures, and Lyrics

```dart
import 'dart:io';

import 'package:dart_taglib/dart_taglib.dart';

final api = TaglibApi();
final bytes = File('my_song.mp3').readAsBytesSync();
final session = api.openSession(bytes, nameHint: 'my_song.mp3');

try {
  final current = session.readBasicTags();
  session.writeBasicTags(
    BasicTags(
      title: 'New Title',
      artist: current.artist,
      album: 'New Album',
      genre: current.genre,
      comment: current.comment,
      lyrics: current.lyrics,
      year: current.year,
      track: current.track,
    ),
    id3v2Version: Id3v2Version.v24,
  );

  session.writePictures(<PictureItem>[
    PictureItem(
      mimeType: 'image/jpeg',
      description: 'Front Cover',
      pictureType: 'Front Cover',
      data: File('cover.jpg').readAsBytesSync(),
    ),
  ], clearExisting: true);

  session.writeLyrics(
    'Updated lyrics',
    language: 'eng',
    description: 'LYRICS',
    id3v2Version: Id3v2Version.v24,
  );

  File('updated_song.mp3').writeAsBytesSync(session.exportBytes());
} finally {
  session.close();
}
```

## License

The package's own code is available under the [MIT License](LICENSE). See
[Third-Party Notices](THIRD_PARTY_NOTICES.md) for the licenses that apply to
the bundled TagLib source and WebAssembly runtime.
