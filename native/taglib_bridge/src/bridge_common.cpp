// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#include "bridge_internal.h"

#include <algorithm>
#include <cctype>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <limits>

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

namespace {
#ifndef _WIN32
class ScopedFileDescriptor final {
public:
  explicit ScopedFileDescriptor(int value) : value_(value) {}
  ~ScopedFileDescriptor()
  {
    if(value_ >= 0) {
      ::close(value_);
    }
  }

  int get() const { return value_; }
  void release() { value_ = -1; }

private:
  int value_;
};
#endif

#define TLB_ABI_FIELD(struct_type, field) \
  { #struct_type, #field, static_cast<uint32_t>(offsetof(struct_type, field)), \
    static_cast<uint32_t>(sizeof(((struct_type *)0)->field)) }

const tlb_abi_field_t kAbiFields[] = {
  TLB_ABI_FIELD(tlb_audio_properties_t, length_seconds),
  TLB_ABI_FIELD(tlb_audio_properties_t, bitrate_kbps),
  TLB_ABI_FIELD(tlb_audio_properties_t, sample_rate),
  TLB_ABI_FIELD(tlb_audio_properties_t, channels),
  TLB_ABI_FIELD(tlb_basic_tags_t, title),
  TLB_ABI_FIELD(tlb_basic_tags_t, artist),
  TLB_ABI_FIELD(tlb_basic_tags_t, album),
  TLB_ABI_FIELD(tlb_basic_tags_t, comment),
  TLB_ABI_FIELD(tlb_basic_tags_t, genre),
  TLB_ABI_FIELD(tlb_basic_tags_t, lyrics),
  TLB_ABI_FIELD(tlb_basic_tags_t, year),
  TLB_ABI_FIELD(tlb_basic_tags_t, track),
  TLB_ABI_FIELD(tlb_session_capabilities_t, plain_lyrics_writable),
  TLB_ABI_FIELD(tlb_session_capabilities_t, synced_lyrics_writable),
  TLB_ABI_FIELD(tlb_session_capabilities_t, mp3_id3_save_supported),
  TLB_ABI_FIELD(tlb_session_capabilities_t, uslt),
  TLB_ABI_FIELD(tlb_session_capabilities_t, lyrics),
  TLB_ABI_FIELD(tlb_session_capabilities_t, mp4_lyr),
  TLB_ABI_FIELD(tlb_session_capabilities_t, wm_lyrics),
  TLB_ABI_FIELD(tlb_session_capabilities_t, hint_based),
  TLB_ABI_FIELD(tlb_property_item_t, key),
  TLB_ABI_FIELD(tlb_property_item_t, values),
  TLB_ABI_FIELD(tlb_property_item_t, value_count),
  TLB_ABI_FIELD(tlb_property_map_t, items),
  TLB_ABI_FIELD(tlb_property_map_t, item_count),
  TLB_ABI_FIELD(tlb_picture_item_t, mime_type),
  TLB_ABI_FIELD(tlb_picture_item_t, description),
  TLB_ABI_FIELD(tlb_picture_item_t, picture_type),
  TLB_ABI_FIELD(tlb_picture_item_t, data),
  TLB_ABI_FIELD(tlb_picture_item_t, data_length),
  TLB_ABI_FIELD(tlb_picture_list_t, items),
  TLB_ABI_FIELD(tlb_picture_list_t, item_count),
  TLB_ABI_FIELD(tlb_sylt_entry_t, time),
  TLB_ABI_FIELD(tlb_sylt_entry_t, text),
  TLB_ABI_FIELD(tlb_sylt_track_t, language),
  TLB_ABI_FIELD(tlb_sylt_track_t, description),
  TLB_ABI_FIELD(tlb_sylt_track_t, type),
  TLB_ABI_FIELD(tlb_sylt_track_t, timestamp_format),
  TLB_ABI_FIELD(tlb_sylt_track_t, entries),
  TLB_ABI_FIELD(tlb_sylt_track_t, entry_count),
  TLB_ABI_FIELD(tlb_sylt_track_list_t, tracks),
  TLB_ABI_FIELD(tlb_sylt_track_list_t, track_count),
  TLB_ABI_FIELD(tlb_sylt_filter_t, language),
  TLB_ABI_FIELD(tlb_sylt_filter_t, description),
  TLB_ABI_FIELD(tlb_sylt_filter_t, type),
  TLB_ABI_FIELD(tlb_text_issue_t, source),
  TLB_ABI_FIELD(tlb_text_issue_t, field_path),
  TLB_ABI_FIELD(tlb_text_issue_t, frame_id),
  TLB_ABI_FIELD(tlb_text_issue_t, language),
  TLB_ABI_FIELD(tlb_text_issue_t, description),
  TLB_ABI_FIELD(tlb_text_issue_t, raw_bytes),
  TLB_ABI_FIELD(tlb_text_issue_t, raw_bytes_length),
  TLB_ABI_FIELD(tlb_text_issue_t, baseline_decoded),
  TLB_ABI_FIELD(tlb_text_issue_list_t, issues),
  TLB_ABI_FIELD(tlb_text_issue_list_t, issue_count),
};

#undef TLB_ABI_FIELD


}  // namespace

namespace tlb::bridge {

namespace {
std::string ToUpperAscii(const std::string &value)
{
  std::string out = value;
  std::transform(out.begin(), out.end(), out.begin(), [](unsigned char ch) {
    return static_cast<char>(std::toupper(ch));
  });
  return out;
}

std::string ToLowerAscii(const std::string &value)
{
  std::string out = value;
  std::transform(out.begin(), out.end(), out.begin(), [](unsigned char ch) {
    return static_cast<char>(std::tolower(ch));
  });
  return out;
}

#ifdef _WIN32
std::wstring Utf8ToWide(const char *value)
{
  if(value == nullptr) {
    return std::wstring();
  }

  UINT code_page = CP_UTF8;
  DWORD flags = MB_ERR_INVALID_CHARS;
  int length = MultiByteToWideChar(code_page, flags, value, -1, nullptr, 0);
  if(length == 0) {
    code_page = CP_ACP;
    flags = 0;
    length = MultiByteToWideChar(code_page, flags, value, -1, nullptr, 0);
  }
  if(length <= 0) {
    return std::wstring();
  }

  std::wstring wide(static_cast<size_t>(length) - 1, L'\0');
  if(MultiByteToWideChar(code_page, flags, value, -1, wide.data(), length) ==
     0) {
    return std::wstring();
  }
  return wide;
}
#endif

TagLib::FileName FileNameFromUtf8(const char *path)
{
#ifdef _WIN32
  std::wstring wide = Utf8ToWide(path);
  return TagLib::FileName(wide.c_str());
#else
  return path;
#endif
}

}  // namespace

char *DupCString(const std::string &value)
{
  char *buffer = static_cast<char *>(std::malloc(value.size() + 1));
  if(buffer == nullptr) {
    return nullptr;
  }
  std::memcpy(buffer, value.data(), value.size());
  buffer[value.size()] = '\0';
  return buffer;
}

char *DupUtf8String(const TagLib::String &value)
{
  return DupCString(value.to8Bit(true));
}

char *DupUtf8StringOrNull(const TagLib::String &value)
{
  if(value.isEmpty()) {
    return nullptr;
  }
  return DupUtf8String(value);
}

uint8_t *DupBytes(const TagLib::ByteVector &value)
{
  if(value.isEmpty()) {
    return nullptr;
  }

  uint8_t *buffer = static_cast<uint8_t *>(std::malloc(value.size()));
  if(buffer == nullptr) {
    return nullptr;
  }

  std::memcpy(buffer, value.data(), value.size());
  return buffer;
}

uint8_t *DupBytes(const std::vector<uint8_t> &value)
{
  if(value.empty()) {
    return nullptr;
  }

  uint8_t *buffer = static_cast<uint8_t *>(std::malloc(value.size()));
  if(buffer == nullptr) {
    return nullptr;
  }

  std::memcpy(buffer, value.data(), value.size());
  return buffer;
}

TagLib::String ToTagString(const char *utf8)
{
  if(utf8 == nullptr) {
    return TagLib::String();
  }
  return TagLib::String(utf8, TagLib::String::UTF8);
}

TagLib::ByteVector NormalizeLanguage(const char *language)
{
  std::string normalized = "eng";

  if(language != nullptr && *language != '\0') {
    normalized.assign(language);
    normalized = ToLowerAscii(normalized);
    if(normalized.size() < 3) {
      normalized.append(3 - normalized.size(), ' ');
    }
    if(normalized.size() > 3) {
      normalized.resize(3);
    }
  }

  return TagLib::ByteVector(normalized.data(), 3);
}

bool MatchOptionalUtf8(const char *filter, const TagLib::String &value)
{
  if(filter == nullptr || *filter == '\0') {
    return true;
  }
  return ToTagString(filter) == value;
}

bool MatchOptionalLanguage(const char *filter, const TagLib::ByteVector &value)
{
  if(filter == nullptr || *filter == '\0') {
    return true;
  }

  TagLib::ByteVector expected = NormalizeLanguage(filter);
  TagLib::ByteVector actual = value;
  if(actual.size() > 3) {
    actual.resize(3);
  }
  if(actual.size() < 3) {
    actual.resize(3, ' ');
  }
  return expected == actual;
}

bool ParseId3v2Version(uint8_t version, TagLib::ID3v2::Version *out_version)
{
  if(out_version == nullptr) {
    return false;
  }

  if(version == static_cast<uint8_t>(TLB_ID3V2_VERSION_23)) {
    *out_version = TagLib::ID3v2::v3;
    return true;
  }
  if(version == static_cast<uint8_t>(TLB_ID3V2_VERSION_24)) {
    *out_version = TagLib::ID3v2::v4;
    return true;
  }
  return false;
}

std::string BuildLyricsPropertyKey(const char *description)
{
  if(description == nullptr || *description == '\0') {
    return "LYRICS";
  }

  const std::string description_string(description);
  if(ToUpperAscii(description_string) == "LYRICS") {
    return "LYRICS";
  }
  return "LYRICS:" + description_string;
}

void FreeBasicTagsMembers(tlb_basic_tags_t *value)
{
  if(value == nullptr) {
    return;
  }

  std::free(value->title);
  std::free(value->artist);
  std::free(value->album);
  std::free(value->comment);
  std::free(value->genre);
  std::free(value->lyrics);
  ZeroStruct(value);
}

void FreePropertyMapMembers(tlb_property_map_t *value)
{
  if(value == nullptr) {
    return;
  }

  if(value->items != nullptr) {
    for(uint32_t i = 0; i < value->item_count; ++i) {
      tlb_property_item_t &item = value->items[i];
      std::free(item.key);

      if(item.values != nullptr) {
        for(uint32_t j = 0; j < item.value_count; ++j) {
          std::free(item.values[j]);
        }
        std::free(item.values);
      }
    }

    std::free(value->items);
  }

  ZeroStruct(value);
}

void FreePictureListMembers(tlb_picture_list_t *value)
{
  if(value == nullptr) {
    return;
  }

  if(value->items != nullptr) {
    for(uint32_t i = 0; i < value->item_count; ++i) {
      tlb_picture_item_t &item = value->items[i];
      std::free(item.mime_type);
      std::free(item.description);
      std::free(item.picture_type);
      std::free(item.data);
    }
    std::free(value->items);
  }

  ZeroStruct(value);
}

void FreeSyltTrackListMembers(tlb_sylt_track_list_t *value)
{
  if(value == nullptr) {
    return;
  }

  if(value->tracks != nullptr) {
    for(uint32_t i = 0; i < value->track_count; ++i) {
      tlb_sylt_track_t &track = value->tracks[i];
      std::free(track.description);

      if(track.entries != nullptr) {
        for(uint32_t j = 0; j < track.entry_count; ++j) {
          std::free(track.entries[j].text);
        }
        std::free(track.entries);
      }
    }
    std::free(value->tracks);
  }

  ZeroStruct(value);
}

void FreeTextIssueListMembers(tlb_text_issue_list_t *value)
{
  if(value == nullptr) {
    return;
  }

  if(value->issues != nullptr) {
    for(uint32_t i = 0; i < value->issue_count; ++i) {
      tlb_text_issue_t &issue = value->issues[i];
      std::free(issue.field_path);
      std::free(issue.frame_id);
      std::free(issue.language);
      std::free(issue.description);
      std::free(issue.raw_bytes);
      std::free(issue.baseline_decoded);
    }
    std::free(value->issues);
  }

  ZeroStruct(value);
}

bool LooksLikeMpegName(const char *name)
{
  if(name == nullptr || *name == '\0') {
    return false;
  }

  const std::string name_text(name);
  const size_t dot_pos = name_text.find_last_of('.');
  if(dot_pos == std::string::npos || dot_pos + 1 >= name_text.size()) {
    return false;
  }

  const std::string extension = ToLowerAscii(name_text.substr(dot_pos + 1));
  return extension == "mp3" || extension == "aac";
}

bool IsValidSession(const tlb_session_t *session)
{
  return session != nullptr &&
         (session->stream != nullptr || session->file_stream != nullptr) &&
         session->file_ref != nullptr;
}

TagLib::FileRef *SessionFileRef(tlb_session_t *session)
{
  if(!IsValidSession(session)) {
    return nullptr;
  }
  return session->file_ref.get();
}

const TagLib::FileRef *SessionFileRef(const tlb_session_t *session)
{
  if(!IsValidSession(session)) {
    return nullptr;
  }
  return session->file_ref.get();
}

TagLib::File *SessionFile(tlb_session_t *session)
{
  TagLib::FileRef *file_ref = SessionFileRef(session);
  if(file_ref == nullptr || file_ref->isNull()) {
    return nullptr;
  }
  return file_ref->file();
}

const TagLib::File *SessionFile(const tlb_session_t *session)
{
  const TagLib::FileRef *file_ref = SessionFileRef(session);
  if(file_ref == nullptr || file_ref->isNull()) {
    return nullptr;
  }
  return file_ref->file();
}

TagLib::MPEG::File *SessionMpegFile(tlb_session_t *session)
{
  return dynamic_cast<TagLib::MPEG::File *>(SessionFile(session));
}

const TagLib::MPEG::File *SessionMpegFile(const tlb_session_t *session)
{
  return dynamic_cast<const TagLib::MPEG::File *>(SessionFile(session));
}

bool SessionLooksLikeMpegName(const tlb_session_t *session)
{
  if(session == nullptr) {
    return false;
  }
  return LooksLikeMpegName(session->name_hint.c_str());
}

}  // namespace tlb::bridge

extern "C" {

uint32_t tlb_api_version(void)
{
  return TLB_API_VERSION_VALUE;
}

uint32_t tlb_abi_field_count(void)
{
  return static_cast<uint32_t>(sizeof(kAbiFields) / sizeof(kAbiFields[0]));
}

const tlb_abi_field_t *tlb_abi_fields(void)
{
  return kAbiFields;
}

const char *tlb_status_message(tlb_status_t status)
{
  switch(status) {
  case TLB_STATUS_OK:
    return "ok";
  case TLB_STATUS_INVALID_ARGUMENT:
    return "invalid argument";
  case TLB_STATUS_IO_ERROR:
    return "io error";
  case TLB_STATUS_UNSUPPORTED_FORMAT:
    return "unsupported format";
  case TLB_STATUS_NOT_FOUND:
    return "not found";
  case TLB_STATUS_TAGLIB_ERROR:
    return "taglib error";
  case TLB_STATUS_OUT_OF_MEMORY:
    return "out of memory";
  case TLB_STATUS_INTERNAL_ERROR:
    return "internal error";
  default:
    return "unknown status";
  }
}

void tlb_free_string(char *value)
{
  std::free(value);
}

void tlb_free_bytes(uint8_t *value)
{
  std::free(value);
}

void tlb_free_basic_tags(tlb_basic_tags_t *value)
{
  tlb::bridge::FreeBasicTagsMembers(value);
}

void tlb_free_property_map(tlb_property_map_t *value)
{
  tlb::bridge::FreePropertyMapMembers(value);
}

void tlb_free_picture_list(tlb_picture_list_t *value)
{
  tlb::bridge::FreePictureListMembers(value);
}

void tlb_free_sylt_track_list(tlb_sylt_track_list_t *value)
{
  tlb::bridge::FreeSyltTrackListMembers(value);
}

void tlb_free_text_issue_list(tlb_text_issue_list_t *value)
{
  tlb::bridge::FreeTextIssueListMembers(value);
}

tlb_status_t tlb_session_open_from_bytes(const uint8_t *bytes,
                                         uint32_t length,
                                         const char *name_hint,
                                         tlb_session_t **out_session)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(bytes == nullptr || length == 0 || out_session == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    *out_session = nullptr;

    auto session = std::make_unique<tlb_session_t>();
    session->name_hint = name_hint == nullptr ? "" : name_hint;

    const TagLib::ByteVector buffer(
      reinterpret_cast<const char *>(bytes),
      static_cast<unsigned int>(length));
    session->stream = std::make_unique<tlb::bridge::NamedByteVectorStream>(
      buffer,
      session->name_hint);
    session->file_ref = std::make_unique<TagLib::FileRef>(session->stream.get(), true);
    if(session->file_ref->isNull() || session->file_ref->file() == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    *out_session = session.release();
    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_open_from_path(const char *path, tlb_session_t **out_session)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(path == nullptr || *path == '\0' || out_session == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    *out_session = nullptr;

    auto session = std::make_unique<tlb_session_t>();
    session->name_hint = path;

    session->file_stream = std::make_unique<TagLib::FileStream>(
      tlb::bridge::FileNameFromUtf8(path),
      false);
    if(!session->file_stream->isOpen()) {
      return TLB_STATUS_IO_ERROR;
    }

    session->file_ref = std::make_unique<TagLib::FileRef>(
      session->file_stream.get(),
      true);
    if(session->file_ref->isNull() || session->file_ref->file() == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    *out_session = session.release();
    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_open_from_fd(int32_t file_descriptor,
                                      const char *name_hint,
                                      tlb_session_t **out_session)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(file_descriptor < 0 || out_session == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    *out_session = nullptr;

#ifdef _WIN32
    (void)name_hint;
    return TLB_STATUS_UNSUPPORTED_FORMAT;
#else
    const int dup_fd = ::dup(file_descriptor);
    if(dup_fd < 0) {
      return TLB_STATUS_IO_ERROR;
    }

    ScopedFileDescriptor fd_guard(dup_fd);
    auto session = std::make_unique<tlb_session_t>();
    session->name_hint = name_hint == nullptr ? "" : name_hint;

    session->file_stream = std::make_unique<TagLib::FileStream>(fd_guard.get(), false);
    if(!session->file_stream->isOpen()) {
      return TLB_STATUS_IO_ERROR;
    }
    // FileStream 仅在成功打开后接管 fd，之前的异常由 guard 负责关闭。
    fd_guard.release();

    session->file_ref = std::make_unique<TagLib::FileRef>(
      session->file_stream.get(),
      true);
    if(session->file_ref->isNull() || session->file_ref->file() == nullptr) {
      return TLB_STATUS_UNSUPPORTED_FORMAT;
    }

    *out_session = session.release();
    return TLB_STATUS_OK;
#endif
  });
}

tlb_status_t tlb_session_close(tlb_session_t **session)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(session == nullptr || *session == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    delete *session;
    *session = nullptr;
    return TLB_STATUS_OK;
  });
}

void tlb_session_finalize(tlb_session_t *session)
{
  // GC 兜底不能向 Dart 或 JavaScript 抛出错误，只负责释放仍存活的会话。
  delete session;
}

tlb_status_t tlb_session_export_bytes(const tlb_session_t *session,
                                      uint8_t **out_bytes,
                                      uint32_t *out_length)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_bytes == nullptr ||
       out_length == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    *out_bytes = nullptr;
    *out_length = 0;

    TagLib::ByteVector stream_bytes;
    TagLib::ByteVector *data = nullptr;
    if(session->stream != nullptr) {
      data = session->stream->data();
    }
    else if(session->file_stream != nullptr) {
      if(!session->file_stream->isOpen()) {
        return TLB_STATUS_IO_ERROR;
      }

      const TagLib::offset_t length = session->file_stream->length();
      if(length < 0) {
        return TLB_STATUS_IO_ERROR;
      }
      if(length == 0) {
        return TLB_STATUS_OK;
      }
      if(length > static_cast<TagLib::offset_t>(
                    (std::numeric_limits<uint32_t>::max)())) {
        return TLB_STATUS_IO_ERROR;
      }

      session->file_stream->seek(0);
      stream_bytes = session->file_stream->readBlock(static_cast<size_t>(length));
      data = &stream_bytes;
    }

    if(data == nullptr || data->isEmpty()) {
      return TLB_STATUS_OK;
    }

    *out_bytes = tlb::bridge::DupBytes(*data);
    if(*out_bytes == nullptr) {
      return TLB_STATUS_OUT_OF_MEMORY;
    }
    *out_length = static_cast<uint32_t>(data->size());
    return TLB_STATUS_OK;
  });
}

}  // extern "C"
