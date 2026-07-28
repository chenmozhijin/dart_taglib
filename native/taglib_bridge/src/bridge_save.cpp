// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#include "bridge_internal.h"

extern "C" {

tlb_status_t tlb_session_mp3_save_with_id3v2_version(tlb_session_t *session, uint8_t version)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session)) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    TagLib::ID3v2::Version parsed_version = TagLib::ID3v2::v4;
    if(!tlb::bridge::ParseId3v2Version(version, &parsed_version)) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    TagLib::MPEG::File *file = tlb::bridge::SessionMpegFile(session);
    if(file == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    if(!file->save(TagLib::MPEG::File::AllTags,
                   TagLib::File::StripOthers,
                   parsed_version,
                   TagLib::File::Duplicate)) {
      return TLB_STATUS_IO_ERROR;
    }

    return TLB_STATUS_OK;
  });
}

}  // extern "C"
