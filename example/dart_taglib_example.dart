// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:dart_taglib/dart_taglib.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stdout.writeln('Usage: dart run example/dart_taglib_example.dart <audio>');
    return;
  }

  final path = arguments.single;
  final result = TaglibApi().readTagsFromPath(path);
  stdout
    ..writeln('Title: ${result.tags.title ?? ''}')
    ..writeln('Artist: ${result.tags.artist ?? ''}')
    ..writeln('Album: ${result.tags.album ?? ''}');
}
