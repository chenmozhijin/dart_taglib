// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

import 'fixture_matrix.dart';
import 'support/fixture_matrix_runner.dart';

String _thirdPartyFixturePath(FixtureCase fixture) {
  if (fixture.relativePath == null) {
    throw StateError('Fixture has no relative path: ${fixture.id}');
  }
  return 'third_party/taglib/tests/data/${fixture.relativePath}';
}

Future<Uint8List> _loadFixtureBytes(FixtureCase fixture) async {
  final file = File(_thirdPartyFixturePath(fixture));
  if (!file.existsSync()) {
    throw StateError('Fixture not found: ${file.path}');
  }
  return file.readAsBytes();
}

FixtureCase _fixtureById(String id) {
  return fixtureMatrix.firstWhere((item) => item.id == id);
}

void main() {
  late TaglibApi api;
  late FixtureMatrixRunner runner;

  setUpAll(() {
    // Like real consumers, the fixture matrix loads the bridge only through
    // Native Assets.
    api = TaglibApi();
    runner = FixtureMatrixRunner(api: api, loadBytes: _loadFixtureBytes);
  });

  group('session fixture matrix (vm)', () {
    for (final fixture in fixtureMatrix) {
      test(
        '${fixture.profile.name} / ${fixture.id}',
        () async => runner.runFixture(fixture),
      );
    }
  });

  group('failure injection semantics (vm)', () {
    test('not-found lyrics semantics on no-tags.m4a after clear', () async {
      final noTagsFixture = _fixtureById('no-tags.m4a');
      final noTagsBytes = await _loadFixtureBytes(noTagsFixture);
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
      final mp3Bytes = await _loadFixtureBytes(mp3Fixture);
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
