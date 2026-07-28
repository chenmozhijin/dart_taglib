// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

import 'fixture_matrix.dart';
import 'support/browser_wasm_loader.dart';
import 'support/fixture_matrix_runner.dart';

const String _fixtureRoot = 'fixtures/taglib_data';

Future<void> _initializeBridge() => initializeTaglibWasmBridge();

FixtureCase _fixtureById(String id) {
  return fixtureMatrix.firstWhere((item) => item.id == id);
}

void main() {
  late TaglibApi api;
  late FixtureMatrixRunner runner;
  final cache = <String, Uint8List>{};

  Future<Uint8List> loadFixtureBytes(FixtureCase fixture) async {
    final relativePath = fixture.relativePath;
    if (relativePath == null) {
      throw StateError('Fixture has no relative path: ${fixture.id}');
    }

    final cached = cache[relativePath];
    if (cached != null) {
      return cached;
    }

    final bytes = await fetchBrowserBytes('$_fixtureRoot/$relativePath');
    cache[relativePath] = bytes;
    return bytes;
  }

  setUpAll(() async {
    await _initializeBridge();
    api = TaglibApi();
    runner = FixtureMatrixRunner(api: api, loadBytes: loadFixtureBytes);
  });

  group('session fixture matrix (browser)', () {
    for (final fixture in fixtureMatrix) {
      test(
        '${fixture.profile.name} / ${fixture.id}',
        () async => runner.runFixture(fixture),
      );
    }
  });

  group('failure injection semantics (browser)', () {
    test('not-found lyrics semantics on no-tags.m4a after clear', () async {
      final noTagsFixture = _fixtureById('no-tags.m4a');
      final noTagsBytes = await loadFixtureBytes(noTagsFixture);
      final noTagsSession = api.openSession(
        noTagsBytes,
        nameHint: noTagsFixture.nameHint,
      );
      try {
        noTagsSession.clearLyrics(
          language: 'eng',
          description: 'LYRICS',
          id3v2Version: Id3v2Version.v24,
        );
        expect(
          noTagsSession.readLyrics(language: 'eng', description: 'LYRICS'),
          isNull,
        );
      } finally {
        noTagsSession.close();
      }

      final mp3Fixture = _fixtureById('bladeenc.mp3');
      final mp3Bytes = await loadFixtureBytes(mp3Fixture);
      final mp3Session = api.openSession(
        mp3Bytes,
        nameHint: mp3Fixture.nameHint,
      );
      try {
        mp3Session.clearSyncedLyrics(id3v2Version: Id3v2Version.v24);
        expect(mp3Session.readSyncedLyrics(), isEmpty);
      } finally {
        mp3Session.close();
      }
    });
  });
}
