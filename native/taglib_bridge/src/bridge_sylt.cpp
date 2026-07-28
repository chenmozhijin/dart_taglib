// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#include "bridge_internal.h"

#include <algorithm>
#include <array>
#include <cstdlib>
#include <vector>

#include "mpeg/id3v2/frames/synchronizedlyricsframe.h"
#include "mpeg/id3v2/id3v2tag.h"
#include "mpeg/mpegfile.h"

using TagLib::ByteVector;
using TagLib::MPEG::File;
using TagLib::String;

namespace {

using SyltFrame = TagLib::ID3v2::SynchronizedLyricsFrame;

ByteVector InputTrackLanguage(const tlb_sylt_track_t &track)
{
  std::array<char, 4> language = {track.language[0], track.language[1], track.language[2], '\0'};
  return tlb::bridge::NormalizeLanguage(language.data());
}

String InputTrackDescription(const tlb_sylt_track_t &track)
{
  if(track.description == nullptr) {
    return String();
  }
  return tlb::bridge::ToTagString(track.description);
}

bool MatchesSyltFilter(const SyltFrame &frame, const tlb_sylt_filter_t *filter)
{
  if(filter == nullptr) {
    return true;
  }
  if(!tlb::bridge::MatchOptionalLanguage(filter->language, frame.language())) {
    return false;
  }
  if(!tlb::bridge::MatchOptionalUtf8(filter->description, frame.description())) {
    return false;
  }
  if(filter->type >= 0 && static_cast<int32_t>(frame.type()) != filter->type) {
    return false;
  }
  return true;
}

bool MatchesSyltTrackKey(const SyltFrame &frame, const tlb_sylt_track_t &track)
{
  if(frame.language() != InputTrackLanguage(track)) {
    return false;
  }
  if(frame.description() != InputTrackDescription(track)) {
    return false;
  }
  return static_cast<uint8_t>(frame.type()) == track.type;
}

void AddUniqueFrame(std::vector<TagLib::ID3v2::Frame *> *frames, TagLib::ID3v2::Frame *frame)
{
  if(std::find(frames->begin(), frames->end(), frame) == frames->end()) {
    frames->push_back(frame);
  }
}

bool FillOutputTrack(const SyltFrame &frame, tlb_sylt_track_t *out_track)
{
  tlb::bridge::ZeroStruct(out_track);

  const ByteVector language = frame.language();
  out_track->language[0] = language.size() > 0 ? language[0] : '\0';
  out_track->language[1] = language.size() > 1 ? language[1] : '\0';
  out_track->language[2] = language.size() > 2 ? language[2] : '\0';
  out_track->language[3] = '\0';

  out_track->description = tlb::bridge::DupUtf8StringOrNull(frame.description());
  if(!frame.description().isEmpty() && out_track->description == nullptr) {
    return false;
  }

  out_track->type = static_cast<uint8_t>(frame.type());
  out_track->timestamp_format = static_cast<uint8_t>(frame.timestampFormat());

  const SyltFrame::SynchedTextList entries = frame.synchedText();
  if(entries.isEmpty()) {
    return true;
  }

  out_track->entries = static_cast<tlb_sylt_entry_t *>(
    std::calloc(entries.size(), sizeof(tlb_sylt_entry_t)));
  if(out_track->entries == nullptr) {
    return false;
  }
  out_track->entry_count = entries.size();

  for(uint32_t i = 0; i < out_track->entry_count; ++i) {
    out_track->entries[i].time = entries[i].time;
    out_track->entries[i].text = tlb::bridge::DupUtf8String(entries[i].text);
    if(out_track->entries[i].text == nullptr) {
      return false;
    }
  }

  return true;
}

tlb_status_t SaveFile(File &file, uint8_t id3v2_version)
{
  TagLib::ID3v2::Version version = TagLib::ID3v2::v4;
  if(!tlb::bridge::ParseId3v2Version(id3v2_version, &version)) {
    return TLB_STATUS_INVALID_ARGUMENT;
  }
  if(!file.save(File::AllTags, TagLib::File::StripOthers, version, File::Duplicate)) {
    return TLB_STATUS_IO_ERROR;
  }
  return TLB_STATUS_OK;
}

}  // namespace

extern "C" {

tlb_status_t tlb_session_mp3_sylt_read(tlb_session_t *session, tlb_sylt_track_list_t *out_tracks)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_tracks == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb::bridge::FreeSyltTrackListMembers(out_tracks);

    File *file = tlb::bridge::SessionMpegFile(session);
    if(file == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    TagLib::ID3v2::Tag *tag = file->ID3v2Tag(false);
    if(tag == nullptr) {
      return TLB_STATUS_NOT_FOUND;
    }

    const TagLib::ID3v2::FrameList &frames = tag->frameList("SYLT");
    if(frames.isEmpty()) {
      return TLB_STATUS_NOT_FOUND;
    }

    out_tracks->tracks = static_cast<tlb_sylt_track_t *>(
      std::calloc(frames.size(), sizeof(tlb_sylt_track_t)));
    if(out_tracks->tracks == nullptr) {
      return TLB_STATUS_OUT_OF_MEMORY;
    }
    out_tracks->track_count = frames.size();

    uint32_t out_index = 0;
    for(auto *frame : frames) {
      auto *sylt_frame = dynamic_cast<SyltFrame *>(frame);
      if(sylt_frame == nullptr) {
        continue;
      }
      if(!FillOutputTrack(*sylt_frame, &out_tracks->tracks[out_index])) {
        tlb::bridge::FreeSyltTrackListMembers(out_tracks);
        return TLB_STATUS_OUT_OF_MEMORY;
      }
      ++out_index;
    }

    out_tracks->track_count = out_index;
    if(out_tracks->track_count == 0) {
      tlb::bridge::FreeSyltTrackListMembers(out_tracks);
      return TLB_STATUS_NOT_FOUND;
    }
    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_mp3_sylt_write(tlb_session_t *session,
                                        const tlb_sylt_track_t *tracks,
                                        uint32_t track_count,
                                        tlb_sylt_merge_mode_t merge_mode,
                                        uint8_t id3v2_version)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) ||
       (track_count > 0 && tracks == nullptr)) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }
    if(merge_mode != TLB_SYLT_MERGE_REPLACE_BY_KEY &&
       merge_mode != TLB_SYLT_MERGE_APPEND &&
       merge_mode != TLB_SYLT_MERGE_REPLACE_ALL) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    File *file = tlb::bridge::SessionMpegFile(session);
    if(file == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    TagLib::ID3v2::Tag *tag = file->ID3v2Tag(true);
    if(tag == nullptr) {
      return TLB_STATUS_TAGLIB_ERROR;
    }

    if(merge_mode == TLB_SYLT_MERGE_REPLACE_ALL) {
      tag->removeFrames("SYLT");
    }
    else if(merge_mode == TLB_SYLT_MERGE_REPLACE_BY_KEY && track_count > 0) {
      std::vector<TagLib::ID3v2::Frame *> to_remove;
      const TagLib::ID3v2::FrameList &existing = tag->frameList("SYLT");

      for(uint32_t i = 0; i < track_count; ++i) {
        for(auto *frame : existing) {
          auto *sylt_frame = dynamic_cast<SyltFrame *>(frame);
          if(sylt_frame == nullptr) {
            continue;
          }
          if(MatchesSyltTrackKey(*sylt_frame, tracks[i])) {
            AddUniqueFrame(&to_remove, frame);
          }
        }
      }

      for(auto *frame : to_remove) {
        tag->removeFrame(frame, true);
      }
    }

    for(uint32_t i = 0; i < track_count; ++i) {
      const tlb_sylt_track_t &track = tracks[i];
      auto frame = std::make_unique<SyltFrame>(String::UTF8);
      frame->setTextEncoding(String::UTF8);
      frame->setLanguage(InputTrackLanguage(track));
      frame->setDescription(InputTrackDescription(track));
      frame->setType(static_cast<SyltFrame::Type>(track.type));
      frame->setTimestampFormat(static_cast<SyltFrame::TimestampFormat>(track.timestamp_format));

      SyltFrame::SynchedTextList entries;
      for(uint32_t j = 0; j < track.entry_count; ++j) {
        const char *text = track.entries[j].text == nullptr ? "" : track.entries[j].text;
        entries.append(SyltFrame::SynchedText(track.entries[j].time, tlb::bridge::ToTagString(text)));
      }
      frame->setSynchedText(entries);

      tag->addFrame(frame.release());
    }

    return SaveFile(*file, id3v2_version);
  });
}

tlb_status_t tlb_session_mp3_sylt_clear(tlb_session_t *session,
                                        const tlb_sylt_filter_t *filter,
                                        uint8_t id3v2_version)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session)) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    File *file = tlb::bridge::SessionMpegFile(session);
    if(file == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    TagLib::ID3v2::Tag *tag = file->ID3v2Tag(false);
    if(tag == nullptr) {
      return TLB_STATUS_OK;
    }

    std::vector<TagLib::ID3v2::Frame *> to_remove;
    const TagLib::ID3v2::FrameList &frames = tag->frameList("SYLT");
    for(auto *frame : frames) {
      auto *sylt_frame = dynamic_cast<SyltFrame *>(frame);
      if(sylt_frame == nullptr) {
        continue;
      }
      if(MatchesSyltFilter(*sylt_frame, filter)) {
        to_remove.push_back(frame);
      }
    }

    if(to_remove.empty()) {
      return TLB_STATUS_OK;
    }

    for(auto *frame : to_remove) {
      tag->removeFrame(frame, true);
    }

    return SaveFile(*file, id3v2_version);
  });
}

}  // extern "C"
