// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// Unit used by timestamps in an ID3 synchronized lyrics frame.
enum SyncedLyricsTimestampFormat {
  /// Unknown or unsupported timestamp format.
  unknown(0),

  /// MPEG frame count.
  mpegFrames(1),

  /// Milliseconds from the start of the audio.
  milliseconds(2);

  /// Creates a format with the bridge ABI [nativeValue].
  const SyncedLyricsTimestampFormat(this.nativeValue);

  /// Numeric value used by the bridge.
  final int nativeValue;

  /// Maps a bridge ABI [value] to a known format.
  static SyncedLyricsTimestampFormat fromNative(int value) {
    return SyncedLyricsTimestampFormat.values.firstWhere(
      (item) => item.nativeValue == value,
      orElse: () => SyncedLyricsTimestampFormat.unknown,
    );
  }
}

/// Semantic content type of a synchronized lyrics track.
enum SyncedLyricsType {
  /// Unspecified content.
  other(0),

  /// Song lyrics.
  lyrics(1),

  /// Text transcription.
  textTranscription(2),

  /// Movement or section names.
  movement(3),

  /// Events such as applause.
  events(4),

  /// Chord changes.
  chord(5),

  /// Trivia or pop-up information.
  trivia(6),

  /// Webpage URLs.
  webpageUrls(7),

  /// Image URLs.
  imageUrls(8);

  /// Creates a type with the bridge ABI [nativeValue].
  const SyncedLyricsType(this.nativeValue);

  /// Numeric value used by the bridge.
  final int nativeValue;

  /// Maps a bridge ABI [value] to a known type.
  static SyncedLyricsType fromNative(int value) {
    return SyncedLyricsType.values.firstWhere(
      (item) => item.nativeValue == value,
      orElse: () => SyncedLyricsType.other,
    );
  }
}

/// One timed string in a synchronized lyrics track.
class SyncedLyricsEntry {
  /// Creates an entry at [time].
  const SyncedLyricsEntry({required this.time, required this.text});

  /// Timestamp expressed in the containing track's timestamp format.
  final int time;

  /// Text displayed at [time].
  final String text;
}

/// One synchronized lyrics track.
class SyncedLyricsTrack {
  /// Creates a track and stores an unmodifiable copy of [entries].
  SyncedLyricsTrack({
    required this.language,
    this.description = '',
    this.type = SyncedLyricsType.lyrics,
    this.timestampFormat = SyncedLyricsTimestampFormat.milliseconds,
    required List<SyncedLyricsEntry> entries,
  }) : entries = List<SyncedLyricsEntry>.unmodifiable(entries);

  /// Three-character ISO-639-2 language code.
  final String language;

  /// Content descriptor used to distinguish multiple tracks.
  final String description;

  /// Semantic content type.
  final SyncedLyricsType type;

  /// Unit used by entry timestamps.
  final SyncedLyricsTimestampFormat timestampFormat;

  /// Unmodifiable ordered timed entries.
  final List<SyncedLyricsEntry> entries;
}

/// Optional selectors for removing synchronized lyrics tracks.
class SyncedLyricsFilter {
  /// Creates a filter; null fields act as wildcards.
  const SyncedLyricsFilter({this.language, this.description, this.type});

  /// Language to match.
  final String? language;

  /// Description to match.
  final String? description;

  /// Content type to match.
  final SyncedLyricsType? type;
}
