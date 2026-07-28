// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#ifndef TLB_BRIDGE_INTERNAL_H
#define TLB_BRIDGE_INTERNAL_H

#include "taglib_bridge.h"

#include <cstring>
#include <exception>
#include <memory>
#include <string>
#include <vector>

#include "fileref.h"
#include "mpeg/mpegfile.h"
#include "mpeg/id3v2/id3v2.h"
#include "toolkit/tbytevector.h"
#include "toolkit/tbytevectorstream.h"
#include "toolkit/tfilestream.h"
#include "toolkit/tstring.h"

namespace tlb::bridge {

class NamedByteVectorStream final : public TagLib::ByteVectorStream {
public:
  NamedByteVectorStream(const TagLib::ByteVector &data, std::string name_hint)
      : TagLib::ByteVectorStream(data), name_hint_(std::move(name_hint))
  {
  }

  TagLib::FileName name() const override
  {
#ifdef _WIN32
    return TagLib::FileName(name_hint_.c_str());
#else
    return name_hint_.c_str();
#endif
  }

  const std::string &nameHint() const
  {
    return name_hint_;
  }

private:
  std::string name_hint_;
};

}  // namespace tlb::bridge

struct tlb_session_t {
  std::unique_ptr<tlb::bridge::NamedByteVectorStream> stream;
  std::unique_ptr<TagLib::FileStream> file_stream;
  std::unique_ptr<TagLib::FileRef> file_ref;
  std::string name_hint;
};

namespace tlb::bridge {

template <typename T>
void ZeroStruct(T *value)
{
  if(value != nullptr) {
    std::memset(value, 0, sizeof(T));
  }
}

template <typename Fn>
tlb_status_t SafeCall(Fn &&fn)
{
  try {
    return fn();
  }
  catch(const std::bad_alloc &) {
    return TLB_STATUS_OUT_OF_MEMORY;
  }
  catch(const std::exception &) {
    return TLB_STATUS_TAGLIB_ERROR;
  }
  catch(...) {
    return TLB_STATUS_INTERNAL_ERROR;
  }
}

char *DupCString(const std::string &value);
char *DupUtf8String(const TagLib::String &value);
char *DupUtf8StringOrNull(const TagLib::String &value);
uint8_t *DupBytes(const TagLib::ByteVector &value);
uint8_t *DupBytes(const std::vector<uint8_t> &value);

TagLib::String ToTagString(const char *utf8);
TagLib::ByteVector NormalizeLanguage(const char *language);
bool MatchOptionalUtf8(const char *filter, const TagLib::String &value);
bool MatchOptionalLanguage(const char *filter, const TagLib::ByteVector &value);

bool ParseId3v2Version(uint8_t version, TagLib::ID3v2::Version *out_version);
std::string BuildLyricsPropertyKey(const char *description);
bool LooksLikeMpegName(const char *name);
bool IsValidSession(const tlb_session_t *session);
TagLib::FileRef *SessionFileRef(tlb_session_t *session);
const TagLib::FileRef *SessionFileRef(const tlb_session_t *session);
TagLib::File *SessionFile(tlb_session_t *session);
const TagLib::File *SessionFile(const tlb_session_t *session);
TagLib::MPEG::File *SessionMpegFile(tlb_session_t *session);
const TagLib::MPEG::File *SessionMpegFile(const tlb_session_t *session);
bool SessionLooksLikeMpegName(const tlb_session_t *session);

void FreeBasicTagsMembers(tlb_basic_tags_t *value);
void FreePropertyMapMembers(tlb_property_map_t *value);
void FreePictureListMembers(tlb_picture_list_t *value);
void FreeSyltTrackListMembers(tlb_sylt_track_list_t *value);
void FreeTextIssueListMembers(tlb_text_issue_list_t *value);

}  // namespace tlb::bridge

#endif
