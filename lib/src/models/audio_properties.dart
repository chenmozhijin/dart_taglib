// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// Technical properties reported for an audio stream.
class AudioProperties {
  /// Creates an immutable property set.
  const AudioProperties({
    required this.lengthSeconds,
    required this.bitrateKbps,
    required this.sampleRate,
    required this.channels,
  });

  /// Whole-second duration reported by TagLib.
  final int lengthSeconds;

  /// Average bitrate in kilobits per second.
  final int bitrateKbps;

  /// Sample rate in hertz.
  final int sampleRate;

  /// Number of audio channels.
  final int channels;
}
