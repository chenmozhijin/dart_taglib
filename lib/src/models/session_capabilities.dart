// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// Operations supported by the current audio format.
class SessionCapabilities {
  /// Creates an immutable capability set.
  const SessionCapabilities({
    required this.plainLyricsWritable,
    required this.syncedLyricsWritable,
    required this.mp3Id3SaveSupported,
    required this.uslt,
    required this.lyrics,
    required this.mp4Lyr,
    required this.wmLyrics,
    required this.hintBased,
  });

  /// Whether plain lyrics can be written.
  final bool plainLyricsWritable;

  /// Whether synchronized lyrics can be written.
  final bool syncedLyricsWritable;

  /// Whether the ID3v2 save version can be selected for MPEG files.
  final bool mp3Id3SaveSupported;

  /// Whether ID3 USLT frames are supported.
  final bool uslt;

  /// Whether generic `LYRICS` properties are supported.
  final bool lyrics;

  /// Whether MP4 `©lyr` atoms are supported.
  final bool mp4Lyr;

  /// Whether ASF `WM/LYRICS` attributes are supported.
  final bool wmLyrics;

  /// Whether this result was inferred from a filename instead of probed.
  final bool hintBased;

  /// Conservative capabilities used when the format is unknown.
  static const SessionCapabilities unknown = SessionCapabilities(
    plainLyricsWritable: false,
    syncedLyricsWritable: false,
    mp3Id3SaveSupported: false,
    uslt: false,
    lyrics: false,
    mp4Lyr: false,
    wmLyrics: false,
    hintBased: true,
  );

  /// Infers capabilities from the extension in [nameHint].
  ///
  /// Returns [unknown] when no supported extension is present.
  static SessionCapabilities fromNameHint(String? nameHint) {
    final descriptor = _TaglibFormatCapabilityDescriptor.fromNameHint(nameHint);
    if (descriptor == null) {
      return unknown;
    }
    return descriptor.toCapabilities(hintBased: true);
  }
}

enum _TaglibLyricsCapabilityKind { mpeg, mp4, asf, propertyMap }

final class _TaglibFormatCapabilityDescriptor {
  const _TaglibFormatCapabilityDescriptor({
    required this.extensions,
    required this.kind,
  });

  final Set<String> extensions;
  final _TaglibLyricsCapabilityKind kind;

  SessionCapabilities toCapabilities({required bool hintBased}) {
    return switch (kind) {
      _TaglibLyricsCapabilityKind.mpeg => SessionCapabilities(
        plainLyricsWritable: true,
        syncedLyricsWritable: true,
        mp3Id3SaveSupported: true,
        uslt: true,
        lyrics: false,
        mp4Lyr: false,
        wmLyrics: false,
        hintBased: hintBased,
      ),
      _TaglibLyricsCapabilityKind.mp4 => SessionCapabilities(
        plainLyricsWritable: true,
        syncedLyricsWritable: false,
        mp3Id3SaveSupported: false,
        uslt: false,
        lyrics: false,
        mp4Lyr: true,
        wmLyrics: false,
        hintBased: hintBased,
      ),
      _TaglibLyricsCapabilityKind.asf => SessionCapabilities(
        plainLyricsWritable: true,
        syncedLyricsWritable: false,
        mp3Id3SaveSupported: false,
        uslt: false,
        lyrics: false,
        mp4Lyr: false,
        wmLyrics: true,
        hintBased: hintBased,
      ),
      _TaglibLyricsCapabilityKind.propertyMap => SessionCapabilities(
        plainLyricsWritable: true,
        syncedLyricsWritable: false,
        mp3Id3SaveSupported: false,
        uslt: false,
        lyrics: true,
        mp4Lyr: false,
        wmLyrics: false,
        hintBased: hintBased,
      ),
    };
  }

  static const List<_TaglibFormatCapabilityDescriptor> values =
      <_TaglibFormatCapabilityDescriptor>[
        _TaglibFormatCapabilityDescriptor(
          kind: _TaglibLyricsCapabilityKind.mpeg,
          extensions: <String>{'mp3', 'aac'},
        ),
        _TaglibFormatCapabilityDescriptor(
          kind: _TaglibLyricsCapabilityKind.mp4,
          extensions: <String>{'m4a', 'm4b', 'mp4', '3g2', '3gp'},
        ),
        _TaglibFormatCapabilityDescriptor(
          kind: _TaglibLyricsCapabilityKind.asf,
          extensions: <String>{'wma', 'asf'},
        ),
        _TaglibFormatCapabilityDescriptor(
          kind: _TaglibLyricsCapabilityKind.propertyMap,
          extensions: <String>{
            'flac',
            'ogg',
            'oga',
            'opus',
            'spx',
            'ape',
            'wv',
            'mpc',
            'tta',
            'wav',
            'aiff',
            'aif',
            'aifc',
            'dsf',
            'dff',
            'mka',
            'mkv',
            'webm',
            'shn',
          },
        ),
      ];

  static _TaglibFormatCapabilityDescriptor? fromNameHint(String? nameHint) {
    final ext = normalizeExtension(nameHint);
    if (ext == null) {
      return null;
    }
    for (final descriptor in values) {
      if (descriptor.extensions.contains(ext)) {
        return descriptor;
      }
    }
    return null;
  }

  static String? normalizeExtension(String? nameHint) {
    if (nameHint == null || nameHint.trim().isEmpty) {
      return null;
    }
    final normalized = nameHint.trim().replaceAll('\\', '/');
    final basename = normalized.split('/').last;
    final dotIndex = basename.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex + 1 >= basename.length) {
      return null;
    }
    return basename.substring(dotIndex + 1).toLowerCase();
  }
}
