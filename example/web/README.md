# Pure Dart Web Example

This example initializes the packaged WebAssembly runtime and reads tags from
an audio file selected in the browser.

From the package root, install the runtime into the example's Web directory and
compile the entry point:

```console
dart run dart_taglib:install_web_runtime --output example/web/assets/packages/dart_taglib/web_runtime
dart compile js --no-source-maps example/web/main.dart -o example/web/main.dart.js
```

Serve `example/web` as the site root, open `index.html`, and select a supported
audio file.
