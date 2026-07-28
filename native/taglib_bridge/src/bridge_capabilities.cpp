// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#include "bridge_internal.h"

#include "ape/apefile.h"
#include "asf/asffile.h"
#include "dsdiff/dsdifffile.h"
#include "dsf/dsffile.h"
#include "flac/flacfile.h"
#include "matroska/matroskafile.h"
#include "mp4/mp4file.h"
#include "mpc/mpcfile.h"
#include "mpeg/mpegfile.h"
#include "ogg/flac/oggflacfile.h"
#include "ogg/opus/opusfile.h"
#include "ogg/speex/speexfile.h"
#include "ogg/vorbis/vorbisfile.h"
#include "riff/aiff/aifffile.h"
#include "riff/wav/wavfile.h"
#include "shorten/shortenfile.h"
#include "trueaudio/trueaudiofile.h"
#include "wavpack/wavpackfile.h"

namespace {

void FillUnknown(tlb_session_capabilities_t *value)
{
  tlb::bridge::ZeroStruct(value);
  if(value != nullptr) {
    value->hint_based = 0;
  }
}

void FillMpeg(tlb_session_capabilities_t *value)
{
  FillUnknown(value);
  value->plain_lyrics_writable = 1;
  value->synced_lyrics_writable = 1;
  value->mp3_id3_save_supported = 1;
  value->uslt = 1;
}

void FillMp4(tlb_session_capabilities_t *value)
{
  FillUnknown(value);
  value->plain_lyrics_writable = 1;
  value->mp4_lyr = 1;
}

void FillAsf(tlb_session_capabilities_t *value)
{
  FillUnknown(value);
  value->plain_lyrics_writable = 1;
  value->wm_lyrics = 1;
}

void FillGenericLyricsProperty(tlb_session_capabilities_t *value)
{
  FillUnknown(value);
  value->plain_lyrics_writable = 1;
  value->lyrics = 1;
}

bool IsGenericLyricsPropertyType(const TagLib::File *file)
{
  return dynamic_cast<const TagLib::FLAC::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::Ogg::Vorbis::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::Ogg::Opus::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::Ogg::FLAC::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::Ogg::Speex::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::APE::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::MPC::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::WavPack::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::TrueAudio::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::RIFF::WAV::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::RIFF::AIFF::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::Matroska::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::DSF::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::DSDIFF::File *>(file) != nullptr ||
         dynamic_cast<const TagLib::Shorten::File *>(file) != nullptr;
}

}  // namespace

extern "C" {

tlb_status_t tlb_session_probe_capabilities(tlb_session_t *session,
                                            tlb_session_capabilities_t *out_capabilities)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_capabilities == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    FillUnknown(out_capabilities);

    const TagLib::File *file = tlb::bridge::SessionFile(session);
    if(file == nullptr) {
      return TLB_STATUS_IO_ERROR;
    }

    if(dynamic_cast<const TagLib::MPEG::File *>(file) != nullptr) {
      FillMpeg(out_capabilities);
      return TLB_STATUS_OK;
    }

    if(dynamic_cast<const TagLib::MP4::File *>(file) != nullptr) {
      FillMp4(out_capabilities);
      return TLB_STATUS_OK;
    }

    if(dynamic_cast<const TagLib::ASF::File *>(file) != nullptr) {
      FillAsf(out_capabilities);
      return TLB_STATUS_OK;
    }

    if(IsGenericLyricsPropertyType(file)) {
      FillGenericLyricsProperty(out_capabilities);
      return TLB_STATUS_OK;
    }

    return TLB_STATUS_OK;
  });
}

}  // extern "C"
