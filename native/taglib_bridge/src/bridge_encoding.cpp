// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#include "bridge_internal.h"

#include <cstdlib>
#include <string>
#include <vector>

#include "taglib_config.h"

#include "mpeg/id3v1/id3v1tag.h"
#include "mpeg/id3v2/frames/commentsframe.h"
#include "mpeg/id3v2/frames/synchronizedlyricsframe.h"
#include "mpeg/id3v2/frames/textidentificationframe.h"
#include "mpeg/id3v2/frames/unsynchronizedlyricsframe.h"
#include "mpeg/id3v2/id3v2tag.h"

#ifdef TAGLIB_WITH_RIFF
#include "riff/wav/infotag.h"
#include "riff/wav/wavfile.h"
#endif

using TagLib::ByteVector;
using TagLib::String;

namespace {

using SyltFrame = TagLib::ID3v2::SynchronizedLyricsFrame;
using TextFrame = TagLib::ID3v2::TextIdentificationFrame;

struct IssueRecord {
  tlb_text_source_t source = TLB_TEXT_SOURCE_ID3V2_LATIN1;
  std::string field_path;
  std::string frame_id;
  std::string language;
  std::string description;
  std::vector<uint8_t> raw_bytes;
  std::string baseline_decoded;
};

std::string ByteVectorToString(const ByteVector &value)
{
  return std::string(value.data(), value.size());
}

std::vector<uint8_t> ByteVectorToBytes(const ByteVector &value)
{
  if(value.isEmpty()) {
    return {};
  }

  const char *data = value.data();
  return std::vector<uint8_t>(reinterpret_cast<const uint8_t *>(data),
                              reinterpret_cast<const uint8_t *>(data) + value.size());
}

std::string LanguageToString(const ByteVector &language)
{
  if(language.isEmpty()) {
    return {};
  }

  std::string text = ByteVectorToString(language);
  while(!text.empty() && (text.back() == '\0' || text.back() == ' ')) {
    text.pop_back();
  }
  return text;
}

void AppendIssue(std::vector<IssueRecord> *issues,
                 tlb_text_source_t source,
                 const std::string &field_path,
                 const std::string &frame_id,
                 const std::string &language,
                 const std::string &description,
                 const std::vector<uint8_t> &raw_bytes,
                 const String &baseline)
{
  if(raw_bytes.empty() && baseline.isEmpty()) {
    return;
  }

  IssueRecord record;
  record.source = source;
  record.field_path = field_path;
  record.frame_id = frame_id;
  record.language = language;
  record.description = description;
  record.raw_bytes = raw_bytes;
  record.baseline_decoded = baseline.to8Bit(true);
  issues->push_back(record);
}

void ScanId3v1(tlb_session_t *session, std::vector<IssueRecord> *issues)
{
  TagLib::MPEG::File *file = tlb::bridge::SessionMpegFile(session);
  if(file == nullptr) {
    return;
  }

  TagLib::ID3v1::Tag *tag = file->ID3v1Tag(false);
  if(tag == nullptr) {
    return;
  }

  auto add_field = [&](const char *name, const String &value) {
    AppendIssue(issues,
                TLB_TEXT_SOURCE_ID3V1,
                std::string("id3v1.") + name,
                "",
                "",
                "",
                ByteVectorToBytes(value.data(String::Latin1)),
                value);
  };

  add_field("title", tag->title());
  add_field("artist", tag->artist());
  add_field("album", tag->album());
  add_field("comment", tag->comment());
  add_field("genre", tag->genre());
}

#ifdef TAGLIB_WITH_RIFF
void ScanRiffInfo(tlb_session_t *session, std::vector<IssueRecord> *issues)
{
  auto *file = dynamic_cast<TagLib::RIFF::WAV::File *>(tlb::bridge::SessionFile(session));
  if(file == nullptr || !file->hasInfoTag()) {
    return;
  }

  const TagLib::RIFF::Info::Tag *tag = file->InfoTag();
  if(tag == nullptr) {
    return;
  }

  const TagLib::RIFF::Info::FieldListMap field_map = tag->fieldListMap();
  for(const auto &[id, value] : field_map) {
    const std::string key = ByteVectorToString(id);
    AppendIssue(issues,
                TLB_TEXT_SOURCE_RIFF_INFO,
                std::string("riff.info.") + key,
                "",
                "",
                "",
                ByteVectorToBytes(value.data(String::Latin1)),
                value);
  }
}
#endif

void ScanId3v2Latin1(tlb_session_t *session, std::vector<IssueRecord> *issues)
{
  TagLib::MPEG::File *file = tlb::bridge::SessionMpegFile(session);
  if(file == nullptr) {
    return;
  }

  TagLib::ID3v2::Tag *tag = file->ID3v2Tag(false);
  if(tag == nullptr) {
    return;
  }

  const TagLib::ID3v2::FrameList frames = tag->frameList();
  for(auto *frame : frames) {
    const std::string frame_id = ByteVectorToString(frame->frameID());

    if(auto *text_frame = dynamic_cast<TextFrame *>(frame)) {
      if(text_frame->textEncoding() != String::Latin1) {
        continue;
      }

      const TagLib::StringList values = text_frame->fieldList();
      for(unsigned int i = 0; i < values.size(); ++i) {
        AppendIssue(issues,
                    TLB_TEXT_SOURCE_ID3V2_LATIN1,
                    "id3v2." + frame_id + "[" + std::to_string(i) + "]",
                    frame_id,
                    "",
                    "",
                    ByteVectorToBytes(values[i].data(String::Latin1)),
                    values[i]);
      }
      continue;
    }

    if(auto *comment = dynamic_cast<TagLib::ID3v2::CommentsFrame *>(frame)) {
      if(comment->textEncoding() != String::Latin1) {
        continue;
      }
      AppendIssue(issues,
                  TLB_TEXT_SOURCE_ID3V2_LATIN1,
                  "id3v2.COMM",
                  "COMM",
                  LanguageToString(comment->language()),
                  comment->description().to8Bit(true),
                  ByteVectorToBytes(comment->text().data(String::Latin1)),
                  comment->text());
      continue;
    }

    if(auto *lyrics = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame)) {
      if(lyrics->textEncoding() != String::Latin1) {
        continue;
      }
      AppendIssue(issues,
                  TLB_TEXT_SOURCE_ID3V2_LATIN1,
                  "id3v2.USLT",
                  "USLT",
                  LanguageToString(lyrics->language()),
                  lyrics->description().to8Bit(true),
                  ByteVectorToBytes(lyrics->text().data(String::Latin1)),
                  lyrics->text());
      continue;
    }

    if(auto *sylt = dynamic_cast<SyltFrame *>(frame)) {
      if(sylt->textEncoding() != String::Latin1) {
        continue;
      }
      const SyltFrame::SynchedTextList entries = sylt->synchedText();
      for(unsigned int i = 0; i < entries.size(); ++i) {
        AppendIssue(issues,
                    TLB_TEXT_SOURCE_ID3V2_LATIN1,
                    "id3v2.SYLT[" + std::to_string(i) + "]",
                    "SYLT",
                    LanguageToString(sylt->language()),
                    sylt->description().to8Bit(true),
                    ByteVectorToBytes(entries[i].text.data(String::Latin1)),
                    entries[i].text);
      }
    }
  }
}

bool FillCIssue(const IssueRecord &record, tlb_text_issue_t *out_issue)
{
  tlb::bridge::ZeroStruct(out_issue);

  out_issue->source = record.source;
  out_issue->field_path = tlb::bridge::DupCString(record.field_path);
  out_issue->frame_id = tlb::bridge::DupCString(record.frame_id);
  out_issue->language = tlb::bridge::DupCString(record.language);
  out_issue->description = tlb::bridge::DupCString(record.description);
  out_issue->raw_bytes = tlb::bridge::DupBytes(record.raw_bytes);
  out_issue->raw_bytes_length = static_cast<uint32_t>(record.raw_bytes.size());
  out_issue->baseline_decoded = tlb::bridge::DupCString(record.baseline_decoded);

  if((!record.field_path.empty() && out_issue->field_path == nullptr) ||
     (!record.frame_id.empty() && out_issue->frame_id == nullptr) ||
     (!record.language.empty() && out_issue->language == nullptr) ||
     (!record.description.empty() && out_issue->description == nullptr) ||
     (!record.raw_bytes.empty() && out_issue->raw_bytes == nullptr) ||
     (!record.baseline_decoded.empty() && out_issue->baseline_decoded == nullptr)) {
    return false;
  }

  return true;
}

}  // namespace

extern "C" {

tlb_status_t tlb_session_text_issues_scan(tlb_session_t *session,
                                          tlb_text_issue_list_t *out_issues)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_issues == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb::bridge::FreeTextIssueListMembers(out_issues);

    std::vector<IssueRecord> records;
    ScanId3v1(session, &records);
#ifdef TAGLIB_WITH_RIFF
    ScanRiffInfo(session, &records);
#endif
    ScanId3v2Latin1(session, &records);

    if(records.empty()) {
      return TLB_STATUS_OK;
    }

    out_issues->issues = static_cast<tlb_text_issue_t *>(
      std::calloc(records.size(), sizeof(tlb_text_issue_t)));
    if(out_issues->issues == nullptr) {
      return TLB_STATUS_OUT_OF_MEMORY;
    }
    out_issues->issue_count = static_cast<uint32_t>(records.size());

    for(uint32_t i = 0; i < out_issues->issue_count; ++i) {
      if(!FillCIssue(records[i], &out_issues->issues[i])) {
        tlb::bridge::FreeTextIssueListMembers(out_issues);
        return TLB_STATUS_OUT_OF_MEMORY;
      }
    }

    return TLB_STATUS_OK;
  });
}

}  // extern "C"
