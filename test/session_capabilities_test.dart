// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

void main() {
  group('SessionCapabilities.fromNameHint', () {
    test('mp3 exposes USLT/SYLT and mp3 id3 save capability', () {
      final capabilities = SessionCapabilities.fromNameHint('demo.mp3');
      expect(capabilities.plainLyricsWritable, isTrue);
      expect(capabilities.syncedLyricsWritable, isTrue);
      expect(capabilities.mp3Id3SaveSupported, isTrue);
      expect(capabilities.uslt, isTrue);
      expect(capabilities.lyrics, isFalse);
      expect(capabilities.mp4Lyr, isFalse);
      expect(capabilities.wmLyrics, isFalse);
    });

    test('aac exposes mpeg capabilities like mp3', () {
      final capabilities = SessionCapabilities.fromNameHint('demo.aac');
      expect(capabilities.plainLyricsWritable, isTrue);
      expect(capabilities.syncedLyricsWritable, isTrue);
      expect(capabilities.mp3Id3SaveSupported, isTrue);
      expect(capabilities.uslt, isTrue);
    });

    test('flac/m4a/wma expose their expected plain-lyrics frame hints', () {
      final flac = SessionCapabilities.fromNameHint('demo.flac');
      expect(flac.plainLyricsWritable, isTrue);
      expect(flac.lyrics, isTrue);
      expect(flac.mp4Lyr, isFalse);
      expect(flac.wmLyrics, isFalse);

      final m4a = SessionCapabilities.fromNameHint('demo.m4a');
      expect(m4a.plainLyricsWritable, isTrue);
      expect(m4a.lyrics, isFalse);
      expect(m4a.mp4Lyr, isTrue);
      expect(m4a.wmLyrics, isFalse);

      final wma = SessionCapabilities.fromNameHint('demo.wma');
      expect(wma.plainLyricsWritable, isTrue);
      expect(wma.lyrics, isFalse);
      expect(wma.mp4Lyr, isFalse);
      expect(wma.wmLyrics, isTrue);

      final webm = SessionCapabilities.fromNameHint('demo.webm');
      expect(webm.plainLyricsWritable, isTrue);
      expect(webm.lyrics, isTrue);
      expect(webm.mp4Lyr, isFalse);
      expect(webm.wmLyrics, isFalse);
    });

    test('unknown extension returns conservative hint', () {
      final capabilities = SessionCapabilities.fromNameHint('demo.unknown');
      expect(capabilities.plainLyricsWritable, isFalse);
      expect(capabilities.syncedLyricsWritable, isFalse);
      expect(capabilities.mp3Id3SaveSupported, isFalse);
      expect(capabilities.hintBased, isTrue);
    });
  });
}
