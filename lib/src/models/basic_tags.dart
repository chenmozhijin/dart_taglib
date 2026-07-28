// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

const Object _keep = Object();

/// Common metadata fields shared by supported audio formats.
class BasicTags {
  /// Creates an immutable set of basic tags.
  const BasicTags({
    this.title,
    this.artist,
    this.album,
    this.comment,
    this.genre,
    this.lyrics,
    this.year = 0,
    this.track = 0,
  });

  /// Track title.
  final String? title;

  /// Primary artist.
  final String? artist;

  /// Album title.
  final String? album;

  /// Free-form comment.
  final String? comment;

  /// Genre name.
  final String? genre;

  /// Plain unsynchronized lyrics.
  final String? lyrics;

  /// Release year, or zero when absent.
  final int year;

  /// Track number, or zero when absent.
  final int track;

  /// Returns a copy with selected fields replaced.
  ///
  /// Omit a nullable string to retain it, or pass null to clear it.
  BasicTags copyWith({
    Object? title = _keep,
    Object? artist = _keep,
    Object? album = _keep,
    Object? comment = _keep,
    Object? genre = _keep,
    Object? lyrics = _keep,
    int? year,
    int? track,
  }) {
    return BasicTags(
      title: _resolveNullableString(title, this.title),
      artist: _resolveNullableString(artist, this.artist),
      album: _resolveNullableString(album, this.album),
      comment: _resolveNullableString(comment, this.comment),
      genre: _resolveNullableString(genre, this.genre),
      lyrics: _resolveNullableString(lyrics, this.lyrics),
      year: year ?? this.year,
      track: track ?? this.track,
    );
  }

  static String? _resolveNullableString(Object? value, String? current) {
    if (identical(value, _keep)) {
      return current;
    }
    if (value == null || value is String) {
      return value as String?;
    }
    throw ArgumentError.value(value, 'value', 'Expected String?');
  }
}
