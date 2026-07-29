# dart_taglib

[TagLib](https://taglib.org/) 的跨平台 Dart 绑定：桌面端和移动端使用原生
FFI，浏览器使用 WebAssembly。

[English](README.md) | [简体中文](README_zh.md)

## 安装

```console
dart pub add dart_taglib
```

## 平台支持

| 平台 | 后端 | 环境要求 |
| --- | --- | --- |
| Windows | 原生 FFI | CMake 和 C/C++ 工具链 |
| Linux | 原生 FFI | CMake 和 C/C++ 工具链 |
| macOS | 原生 FFI | CMake 和 Xcode 命令行工具 |
| Android | 原生 FFI | Android NDK 和 CMake |
| iOS | 原生 FFI | macOS、Xcode 和 CMake |
| Web | WebAssembly | 按下文初始化运行时 |

构建应用时会自动构建原生库。

## Web 设置

在 Web 平台创建 `TaglibApi` 前调用 `initializeTaglibWasmBridge()`。

```dart
import 'package:dart_taglib/dart_taglib.dart';

Future<void> main() async {
  await initializeTaglibWasmBridge();
  final api = TaglibApi();
  // 使用 api 启动应用。
}
```

### Flutter Web

Flutter 会自动把 JavaScript 和 WebAssembly 运行时打包到默认的 package asset
地址，无需执行复制命令，也无需在 `index.html` 中添加脚本标签。

### 纯 Dart Web

编译或部署应用前，在应用根目录安装 package 内附带的运行时：

```console
dart run dart_taglib:install_web_runtime
```

默认目标目录是 `web/assets/packages/dart_taglib/web_runtime`，与
`initializeTaglibWasmBridge()` 使用的默认 URL 一致。部署应用前可以执行只读校验：

```console
dart run dart_taglib:install_web_runtime --check
```

如需使用自定义同源目录，请让输出目录和运行时 URL 保持一致：

```console
dart run dart_taglib:install_web_runtime --output web/vendor/dart_taglib
```

```dart
await initializeTaglibWasmBridge(assetBaseUrl: 'vendor/dart_taglib/');
```

## 使用方法

大多数操作从 `TaglibApi` 开始。Session 会持有原生或 WebAssembly 资源，请在
`finally` 中关闭。

### 读取标签

```dart
import 'dart:io';

import 'package:dart_taglib/dart_taglib.dart';

final api = TaglibApi();
final bytes = File('my_song.mp3').readAsBytesSync();
final result = api.readTagsFromBytes(bytes);

print(result.tags.title);
print(result.tags.artist);
```

### 写入标签、封面和歌词

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

## 许可证

项目自有代码采用 [MIT 许可证](LICENSE)。内附 TagLib 源码和 WebAssembly
运行时适用的许可证请参阅[第三方声明](THIRD_PARTY_NOTICES.md)。
