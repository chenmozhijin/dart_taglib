// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

const int statusOk = 0;
const int statusInvalidArgument = 1;
const int statusUnsupportedFormat = 3;
const int statusNotFound = 4;

enum FixtureProfile { mp3Full, genericRw, readOnly, openFail }

final class FixtureCase {
  const FixtureCase({
    required this.id,
    required this.profile,
    required this.nameHint,
    this.relativePath,
    this.expectedOpenStatus = statusOk,
    this.expectedSaveMp3Status = statusUnsupportedFormat,
    this.useEmptyBytes = false,
  });

  final String id;
  final FixtureProfile profile;
  final String nameHint;
  final String? relativePath;
  final int expectedOpenStatus;
  final int expectedSaveMp3Status;
  final bool useEmptyBytes;

  Uint8List buildDefaultBytes(Uint8List loadedBytes) {
    if (useEmptyBytes) {
      return Uint8List(0);
    }
    return loadedBytes;
  }
}

const List<FixtureCase> fixtureMatrix = <FixtureCase>[
  // mp3Full
  FixtureCase(
    id: 'bladeenc.mp3',
    profile: FixtureProfile.mp3Full,
    relativePath: 'bladeenc.mp3',
    nameHint: 'bladeenc.mp3',
    expectedSaveMp3Status: statusOk,
  ),
  FixtureCase(
    id: 'lame_cbr.mp3',
    profile: FixtureProfile.mp3Full,
    relativePath: 'lame_cbr.mp3',
    nameHint: 'lame_cbr.mp3',
    expectedSaveMp3Status: statusOk,
  ),
  FixtureCase(
    id: 'lame_vbr.mp3',
    profile: FixtureProfile.mp3Full,
    relativePath: 'lame_vbr.mp3',
    nameHint: 'lame_vbr.mp3',
    expectedSaveMp3Status: statusOk,
  ),
  FixtureCase(
    id: 'id3v22-tda.mp3',
    profile: FixtureProfile.mp3Full,
    relativePath: 'id3v22-tda.mp3',
    nameHint: 'id3v22-tda.mp3',
    expectedSaveMp3Status: statusOk,
  ),
  FixtureCase(
    id: 'xing.mp3',
    profile: FixtureProfile.mp3Full,
    relativePath: 'xing.mp3',
    nameHint: 'xing.mp3',
    expectedSaveMp3Status: statusOk,
  ),

  // genericRw
  FixtureCase(
    id: 'empty1s.aac',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty1s.aac',
    nameHint: 'empty1s.aac',
    expectedSaveMp3Status: statusOk,
  ),
  FixtureCase(
    id: 'has-tags.m4a',
    profile: FixtureProfile.genericRw,
    relativePath: 'has-tags.m4a',
    nameHint: 'has-tags.m4a',
  ),
  FixtureCase(
    id: 'no-tags.m4a',
    profile: FixtureProfile.genericRw,
    relativePath: 'no-tags.m4a',
    nameHint: 'no-tags.m4a',
  ),
  FixtureCase(
    id: 'empty_alac.m4a',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty_alac.m4a',
    nameHint: 'empty_alac.m4a',
  ),
  FixtureCase(
    id: '64bit.mp4',
    profile: FixtureProfile.genericRw,
    relativePath: '64bit.mp4',
    nameHint: '64bit.mp4',
    expectedOpenStatus: statusUnsupportedFormat,
  ),
  FixtureCase(
    id: 'no-tags.flac',
    profile: FixtureProfile.genericRw,
    relativePath: 'no-tags.flac',
    nameHint: 'no-tags.flac',
  ),
  FixtureCase(
    id: 'multiple-vc.flac',
    profile: FixtureProfile.genericRw,
    relativePath: 'multiple-vc.flac',
    nameHint: 'multiple-vc.flac',
  ),
  FixtureCase(
    id: 'empty.ogg',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty.ogg',
    nameHint: 'empty.ogg',
  ),
  FixtureCase(
    id: 'empty_flac.oga',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty_flac.oga',
    nameHint: 'empty_flac.oga',
  ),
  FixtureCase(
    id: 'empty_vorbis.oga',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty_vorbis.oga',
    nameHint: 'empty_vorbis.oga',
  ),
  FixtureCase(
    id: 'correctness_gain_silent_output.opus',
    profile: FixtureProfile.genericRw,
    relativePath: 'correctness_gain_silent_output.opus',
    nameHint: 'correctness_gain_silent_output.opus',
  ),
  FixtureCase(
    id: 'empty.spx',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty.spx',
    nameHint: 'empty.spx',
  ),
  FixtureCase(
    id: 'mac-399-tagged.ape',
    profile: FixtureProfile.genericRw,
    relativePath: 'mac-399-tagged.ape',
    nameHint: 'mac-399-tagged.ape',
  ),
  FixtureCase(
    id: 'click.mpc',
    profile: FixtureProfile.genericRw,
    relativePath: 'click.mpc',
    nameHint: 'click.mpc',
  ),
  FixtureCase(
    id: 'click.wv',
    profile: FixtureProfile.genericRw,
    relativePath: 'click.wv',
    nameHint: 'click.wv',
  ),
  FixtureCase(
    id: 'tagged.tta',
    profile: FixtureProfile.genericRw,
    relativePath: 'tagged.tta',
    nameHint: 'tagged.tta',
  ),
  FixtureCase(
    id: 'empty.wav',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty.wav',
    nameHint: 'empty.wav',
  ),
  FixtureCase(
    id: 'alaw.wav',
    profile: FixtureProfile.genericRw,
    relativePath: 'alaw.wav',
    nameHint: 'alaw.wav',
  ),
  FixtureCase(
    id: 'empty.aiff',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty.aiff',
    nameHint: 'empty.aiff',
  ),
  FixtureCase(
    id: 'alaw.aifc',
    profile: FixtureProfile.genericRw,
    relativePath: 'alaw.aifc',
    nameHint: 'alaw.aifc',
  ),
  FixtureCase(
    id: 'silence-1.wma',
    profile: FixtureProfile.genericRw,
    relativePath: 'silence-1.wma',
    nameHint: 'silence-1.wma',
  ),
  FixtureCase(
    id: 'lossless.wma',
    profile: FixtureProfile.genericRw,
    relativePath: 'lossless.wma',
    nameHint: 'lossless.wma',
  ),
  FixtureCase(
    id: 'empty10ms.dsf',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty10ms.dsf',
    nameHint: 'empty10ms.dsf',
  ),
  FixtureCase(
    id: 'empty10ms.dff',
    profile: FixtureProfile.genericRw,
    relativePath: 'empty10ms.dff',
    nameHint: 'empty10ms.dff',
  ),
  FixtureCase(
    id: 'no-tags.mka',
    profile: FixtureProfile.genericRw,
    relativePath: 'no-tags.mka',
    nameHint: 'no-tags.mka',
  ),
  FixtureCase(
    id: 'no-tags.webm',
    profile: FixtureProfile.genericRw,
    relativePath: 'no-tags.webm',
    nameHint: 'no-tags.webm',
  ),
  FixtureCase(
    id: 'optimized.mkv',
    profile: FixtureProfile.genericRw,
    relativePath: 'optimized.mkv',
    nameHint: 'optimized.mkv',
  ),

  // readOnly
  FixtureCase(
    id: 'changed.mod',
    profile: FixtureProfile.readOnly,
    relativePath: 'changed.mod',
    nameHint: 'changed.mod',
  ),
  FixtureCase(
    id: 'test.it',
    profile: FixtureProfile.readOnly,
    relativePath: 'test.it',
    nameHint: 'test.it',
  ),
  FixtureCase(
    id: 'changed.s3m',
    profile: FixtureProfile.readOnly,
    relativePath: 'changed.s3m',
    nameHint: 'changed.s3m',
  ),
  FixtureCase(
    id: 'changed.xm',
    profile: FixtureProfile.readOnly,
    relativePath: 'changed.xm',
    nameHint: 'changed.xm',
  ),

  // openFail
  FixtureCase(
    id: 'unsupported-extension.xx',
    profile: FixtureProfile.openFail,
    relativePath: 'unsupported-extension.xx',
    nameHint: 'unsupported-extension.xx',
    expectedOpenStatus: statusUnsupportedFormat,
  ),
  FixtureCase(
    id: 'no-extension',
    profile: FixtureProfile.openFail,
    relativePath: 'no-extension',
    nameHint: 'no-extension',
    expectedOpenStatus: statusUnsupportedFormat,
  ),
  FixtureCase(
    id: 'emptyBytes',
    profile: FixtureProfile.openFail,
    nameHint: 'empty.mp3',
    useEmptyBytes: true,
    expectedOpenStatus: statusInvalidArgument,
  ),
];
