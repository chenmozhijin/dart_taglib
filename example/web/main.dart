// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:js_interop';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  final status = web.document.querySelector('#status') as web.HTMLElement;
  final input =
      web.document.querySelector('#audio-file') as web.HTMLInputElement;

  await initializeTaglibWasmBridge();
  status.textContent = 'Runtime ready. Select an audio file.';

  input.onChange.listen((_) async {
    final file = input.files?.item(0);
    if (file == null) return;

    status.textContent = 'Reading ${file.name}...';
    try {
      final buffer = await file.arrayBuffer().toDart;
      final session = TaglibApi().openSession(
        buffer.toDart.asUint8List(),
        nameHint: file.name,
      );
      try {
        final tags = session.readBasicTags();
        status.textContent = <String>[
          'Title: ${tags.title ?? ''}',
          'Artist: ${tags.artist ?? ''}',
          'Album: ${tags.album ?? ''}',
        ].join('\n');
      } finally {
        session.close();
      }
    } on Object catch (error) {
      status.textContent = 'Unable to read tags: $error';
    }
  });
}
