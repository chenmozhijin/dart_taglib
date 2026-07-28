// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#include "bridge_internal.h"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <limits>
#include <string>
#include <vector>

#include "audioproperties.h"
#include "mpeg/id3v2/frames/unsynchronizedlyricsframe.h"
#include "mpeg/id3v2/id3v2tag.h"
#include "tag.h"
#include "toolkit/tpropertymap.h"
#include "toolkit/tvariant.h"

using TagLib::AudioProperties;
using TagLib::ByteVector;
using TagLib::File;
using TagLib::List;
using TagLib::PropertyMap;
using TagLib::String;
using TagLib::StringList;
using TagLib::Tag;
using TagLib::Variant;
using TagLib::VariantMap;

namespace {

tlb_status_t SaveMpegFileWithVersion(TagLib::MPEG::File &file, uint8_t id3v2_version)
{
  TagLib::ID3v2::Version version = TagLib::ID3v2::v4;
  if(!tlb::bridge::ParseId3v2Version(id3v2_version, &version)) {
    return TLB_STATUS_INVALID_ARGUMENT;
  }

  if(!file.save(TagLib::MPEG::File::AllTags, File::StripOthers, version, File::Duplicate)) {
    return TLB_STATUS_IO_ERROR;
  }
  return TLB_STATUS_OK;
}

bool CopyStringArray(const StringList &values, char ***out_values)
{
  *out_values = nullptr;

  if(values.isEmpty()) {
    return true;
  }

  char **buffer = static_cast<char **>(std::calloc(values.size(), sizeof(char *)));
  if(buffer == nullptr) {
    return false;
  }

  for(unsigned int i = 0; i < values.size(); ++i) {
    buffer[i] = tlb::bridge::DupUtf8String(values[i]);
    if(buffer[i] == nullptr) {
      for(unsigned int j = 0; j < i; ++j) {
        std::free(buffer[j]);
      }
      std::free(buffer);
      return false;
    }
  }

  *out_values = buffer;
  return true;
}

bool FillPictureItemFromVariantMap(const VariantMap &map, tlb_picture_item_t *out_item)
{
  tlb::bridge::ZeroStruct(out_item);

  for(const auto &[key, value] : map) {
    if(key == "data" && value.type() == Variant::ByteVector) {
      const ByteVector bytes = value.value<ByteVector>();
      out_item->data = tlb::bridge::DupBytes(bytes);
      out_item->data_length = bytes.size();
      if(out_item->data_length > 0 && out_item->data == nullptr) {
        return false;
      }
      continue;
    }

    if(value.type() != Variant::String) {
      continue;
    }

    const String text = value.value<String>();
    if(key == "mimeType") {
      out_item->mime_type = tlb::bridge::DupUtf8StringOrNull(text);
      if(!text.isEmpty() && out_item->mime_type == nullptr) {
        return false;
      }
    }
    else if(key == "description") {
      out_item->description = tlb::bridge::DupUtf8StringOrNull(text);
      if(!text.isEmpty() && out_item->description == nullptr) {
        return false;
      }
    }
    else if(key == "pictureType") {
      out_item->picture_type = tlb::bridge::DupUtf8StringOrNull(text);
      if(!text.isEmpty() && out_item->picture_type == nullptr) {
        return false;
      }
    }
  }

  return true;
}

VariantMap BuildVariantMapFromPictureItem(const tlb_picture_item_t &item)
{
  VariantMap map;
  if(item.data != nullptr && item.data_length > 0) {
    map.insert("data", ByteVector(reinterpret_cast<const char *>(item.data), item.data_length));
  }
  if(item.mime_type != nullptr) {
    map.insert("mimeType", tlb::bridge::ToTagString(item.mime_type));
  }
  if(item.description != nullptr) {
    map.insert("description", tlb::bridge::ToTagString(item.description));
  }
  if(item.picture_type != nullptr) {
    map.insert("pictureType", tlb::bridge::ToTagString(item.picture_type));
  }
  return map;
}

tlb_status_t BuildVariantMapFromPictureFileItem(const tlb_picture_file_item_t &item,
                                                VariantMap *out_map)
{
  if(item.path == nullptr || out_map == nullptr) {
    return TLB_STATUS_INVALID_ARGUMENT;
  }

  std::ifstream stream(std::filesystem::u8path(item.path),
                       std::ios::binary | std::ios::ate);
  if(!stream.is_open()) {
    return TLB_STATUS_IO_ERROR;
  }
  const std::streamoff length = stream.tellg();
  if(length < 0 ||
     static_cast<uint64_t>(length) > std::numeric_limits<unsigned int>::max()) {
    return TLB_STATUS_INVALID_ARGUMENT;
  }
  stream.seekg(0, std::ios::beg);
  ByteVector data(static_cast<unsigned int>(length), 0);
  if(length > 0 &&
     !stream.read(data.data(), static_cast<std::streamsize>(length))) {
    return TLB_STATUS_IO_ERROR;
  }

  VariantMap map;
  map.insert("data", data);
  if(item.mime_type != nullptr) {
    map.insert("mimeType", tlb::bridge::ToTagString(item.mime_type));
  }
  if(item.description != nullptr) {
    map.insert("description", tlb::bridge::ToTagString(item.description));
  }
  if(item.picture_type != nullptr) {
    map.insert("pictureType", tlb::bridge::ToTagString(item.picture_type));
  }
  *out_map = map;
  return TLB_STATUS_OK;
}

tlb_status_t WritePictureMaps(tlb_session_t *session,
                              const List<VariantMap> &pictures,
                              uint8_t clear_existing)
{
  TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
  if(file_ref == nullptr || file_ref->isNull()) {
    return TLB_STATUS_IO_ERROR;
  }

  List<VariantMap> mapped_pictures;
  if(!clear_existing) {
    mapped_pictures = file_ref->complexProperties("PICTURE");
  }
  for(const VariantMap &picture : pictures) {
    mapped_pictures.append(picture);
  }
  if(!file_ref->setComplexProperties("PICTURE", mapped_pictures)) {
    return TLB_STATUS_TAGLIB_ERROR;
  }
  return file_ref->save() ? TLB_STATUS_OK : TLB_STATUS_IO_ERROR;
}

tlb_status_t ReadLyricsFromMpeg(tlb_session_t *session,
                                const char *language,
                                const char *description,
                                char **out_lyrics)
{
  TagLib::MPEG::File *file = tlb::bridge::SessionMpegFile(session);
  if(file == nullptr) {
    return TLB_STATUS_UNSUPPORTED_FORMAT;
  }

  TagLib::ID3v2::Tag *tag = file->ID3v2Tag(false);
  if(tag == nullptr) {
    return TLB_STATUS_NOT_FOUND;
  }

  const TagLib::ID3v2::FrameList &frames = tag->frameList("USLT");
  for(auto *frame : frames) {
    auto *lyrics_frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
    if(lyrics_frame == nullptr) {
      continue;
    }

    if(!tlb::bridge::MatchOptionalLanguage(language, lyrics_frame->language())) {
      continue;
    }
    if(!tlb::bridge::MatchOptionalUtf8(description, lyrics_frame->description())) {
      continue;
    }

    *out_lyrics = tlb::bridge::DupUtf8String(lyrics_frame->text());
    if(*out_lyrics == nullptr) {
      return TLB_STATUS_OUT_OF_MEMORY;
    }
    return TLB_STATUS_OK;
  }

  return TLB_STATUS_NOT_FOUND;
}

tlb_status_t ReadLyricsFromPropertyMap(tlb_session_t *session,
                                       const char *description,
                                       char **out_lyrics)
{
  TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
  if(file_ref == nullptr || file_ref->isNull()) {
    return TLB_STATUS_IO_ERROR;
  }

  const PropertyMap map = file_ref->properties();
  const std::string requested_key = tlb::bridge::BuildLyricsPropertyKey(description);
  StringList values = map.value(tlb::bridge::ToTagString(requested_key.c_str()));

  if(values.isEmpty() && (description == nullptr || *description == '\0')) {
    for(const auto &[key, property_values] : map) {
      if(key == "LYRICS" || key.startsWith("LYRICS:")) {
        values = property_values;
        break;
      }
    }
  }

  if(values.isEmpty()) {
    return TLB_STATUS_NOT_FOUND;
  }

  *out_lyrics = tlb::bridge::DupUtf8String(values.front());
  if(*out_lyrics == nullptr) {
    return TLB_STATUS_OUT_OF_MEMORY;
  }
  return TLB_STATUS_OK;
}

tlb_status_t WriteLyricsToMpeg(tlb_session_t *session,
                               const char *text,
                               const char *language,
                               const char *description,
                               uint8_t id3v2_version)
{
  TagLib::MPEG::File *file = tlb::bridge::SessionMpegFile(session);
  if(file == nullptr) {
    return TLB_STATUS_UNSUPPORTED_FORMAT;
  }

  TagLib::ID3v2::Tag *tag = file->ID3v2Tag(true);
  if(tag == nullptr) {
    return TLB_STATUS_TAGLIB_ERROR;
  }

  const ByteVector target_language = tlb::bridge::NormalizeLanguage(language);
  const String target_description = tlb::bridge::ToTagString(
    (description == nullptr || *description == '\0') ? "LYRICS" : description);

  std::vector<TagLib::ID3v2::Frame *> to_remove;
  const TagLib::ID3v2::FrameList &frames = tag->frameList("USLT");
  for(auto *frame : frames) {
    auto *lyrics_frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
    if(lyrics_frame == nullptr) {
      continue;
    }
    if(lyrics_frame->language() == target_language &&
       lyrics_frame->description() == target_description) {
      to_remove.push_back(frame);
    }
  }

  for(auto *frame : to_remove) {
    tag->removeFrame(frame, true);
  }

  auto new_frame = std::make_unique<TagLib::ID3v2::UnsynchronizedLyricsFrame>(String::UTF8);
  new_frame->setTextEncoding(String::UTF8);
  new_frame->setLanguage(target_language);
  new_frame->setDescription(target_description);
  new_frame->setText(tlb::bridge::ToTagString(text));
  tag->addFrame(new_frame.release());

  return SaveMpegFileWithVersion(*file, id3v2_version);
}

tlb_status_t ClearLyricsFromMpeg(tlb_session_t *session,
                                 const char *language,
                                 const char *description,
                                 uint8_t id3v2_version)
{
  TagLib::MPEG::File *file = tlb::bridge::SessionMpegFile(session);
  if(file == nullptr) {
    return TLB_STATUS_UNSUPPORTED_FORMAT;
  }

  TagLib::ID3v2::Tag *tag = file->ID3v2Tag(false);
  if(tag == nullptr) {
    return TLB_STATUS_OK;
  }

  std::vector<TagLib::ID3v2::Frame *> to_remove;
  const TagLib::ID3v2::FrameList &frames = tag->frameList("USLT");
  for(auto *frame : frames) {
    auto *lyrics_frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
    if(lyrics_frame == nullptr) {
      continue;
    }
    if(!tlb::bridge::MatchOptionalLanguage(language, lyrics_frame->language())) {
      continue;
    }
    if(!tlb::bridge::MatchOptionalUtf8(description, lyrics_frame->description())) {
      continue;
    }
    to_remove.push_back(frame);
  }

  if(to_remove.empty()) {
    return TLB_STATUS_OK;
  }

  for(auto *frame : to_remove) {
    tag->removeFrame(frame, true);
  }

  return SaveMpegFileWithVersion(*file, id3v2_version);
}

tlb_status_t WriteLyricsToPropertyMap(tlb_session_t *session,
                                      const char *text,
                                      const char *description)
{
  TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
  if(file_ref == nullptr || file_ref->isNull()) {
    return TLB_STATUS_IO_ERROR;
  }

  PropertyMap map = file_ref->properties();
  const std::string key = tlb::bridge::BuildLyricsPropertyKey(description);
  if(!map.replace(tlb::bridge::ToTagString(key.c_str()), StringList(tlb::bridge::ToTagString(text)))) {
    return TLB_STATUS_INVALID_ARGUMENT;
  }

  file_ref->setProperties(map);
  if(!file_ref->save()) {
    return TLB_STATUS_IO_ERROR;
  }
  return TLB_STATUS_OK;
}

tlb_status_t ClearLyricsFromPropertyMap(tlb_session_t *session, const char *description)
{
  TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
  if(file_ref == nullptr || file_ref->isNull()) {
    return TLB_STATUS_IO_ERROR;
  }

  PropertyMap map = file_ref->properties();
  if(description == nullptr || *description == '\0') {
    map.erase("LYRICS");
    std::vector<String> keys_to_remove;
    for(const auto &[key, _] : map) {
      if(key.startsWith("LYRICS:")) {
        keys_to_remove.push_back(key);
      }
    }
    for(const String &key : keys_to_remove) {
      map.erase(key);
    }
  }
  else {
    const std::string key = tlb::bridge::BuildLyricsPropertyKey(description);
    map.erase(tlb::bridge::ToTagString(key.c_str()));
  }

  file_ref->setProperties(map);
  if(!file_ref->save()) {
    return TLB_STATUS_IO_ERROR;
  }
  return TLB_STATUS_OK;
}


tlb_status_t ApplyLyricsToMpegWithoutSave(TagLib::MPEG::File *file,
                                          const char *text,
                                          const char *language,
                                          const char *description)
{
  if(file == nullptr) {
    return TLB_STATUS_UNSUPPORTED_FORMAT;
  }
  TagLib::ID3v2::Tag *tag = file->ID3v2Tag(true);
  if(tag == nullptr) {
    return TLB_STATUS_TAGLIB_ERROR;
  }
  const ByteVector target_language = tlb::bridge::NormalizeLanguage(language);
  const String target_description = tlb::bridge::ToTagString(
    (description == nullptr || *description == '\0') ? "LYRICS" : description);
  std::vector<TagLib::ID3v2::Frame *> to_remove;
  const TagLib::ID3v2::FrameList &frames = tag->frameList("USLT");
  for(auto *frame : frames) {
    auto *lyrics_frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
    if(lyrics_frame != nullptr && lyrics_frame->language() == target_language &&
       lyrics_frame->description() == target_description) {
      to_remove.push_back(frame);
    }
  }
  for(auto *frame : to_remove) {
    tag->removeFrame(frame, true);
  }
  if(text == nullptr || *text == '\0') {
    return TLB_STATUS_OK;
  }
  auto new_frame = std::make_unique<TagLib::ID3v2::UnsynchronizedLyricsFrame>(String::UTF8);
  new_frame->setTextEncoding(String::UTF8);
  new_frame->setLanguage(target_language);
  new_frame->setDescription(target_description);
  new_frame->setText(tlb::bridge::ToTagString(text));
  tag->addFrame(new_frame.release());
  return TLB_STATUS_OK;
}

tlb_status_t ApplyLyricsToPropertyMapWithoutSave(TagLib::FileRef *file_ref,
                                                 const char *text,
                                                 const char *description)
{
  if(file_ref == nullptr || file_ref->isNull()) {
    return TLB_STATUS_IO_ERROR;
  }
  if(text == nullptr) {
    return TLB_STATUS_OK;
  }
  PropertyMap map = file_ref->properties();
  if(*text == '\0') {
    if(description == nullptr || *description == '\0') {
      map.erase("LYRICS");
      std::vector<String> keys_to_remove;
      for(const auto &[key, _] : map) {
        if(key.startsWith("LYRICS:")) {
          keys_to_remove.push_back(key);
        }
      }
      for(const String &key : keys_to_remove) {
        map.erase(key);
      }
    }
    else {
      const std::string key = tlb::bridge::BuildLyricsPropertyKey(description);
      map.erase(tlb::bridge::ToTagString(key.c_str()));
    }
  }
  else {
    const std::string key = tlb::bridge::BuildLyricsPropertyKey(description);
    if(!map.replace(tlb::bridge::ToTagString(key.c_str()),
                    StringList(tlb::bridge::ToTagString(text)))) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }
  }
  file_ref->setProperties(map);
  return TLB_STATUS_OK;
}
}  // namespace

extern "C" {

tlb_status_t tlb_session_read_lyrics(tlb_session_t *session,
                                     const char *language,
                                     const char *description,
                                     char **out_lyrics)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_lyrics == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    *out_lyrics = nullptr;
    tlb_status_t status = ReadLyricsFromMpeg(session, language, description, out_lyrics);
    if(status == TLB_STATUS_OK) {
      return TLB_STATUS_OK;
    }
    if(status != TLB_STATUS_UNSUPPORTED_FORMAT && status != TLB_STATUS_NOT_FOUND) {
      return status;
    }

    if(tlb::bridge::SessionLooksLikeMpegName(session)) {
      return TLB_STATUS_NOT_FOUND;
    }
    return ReadLyricsFromPropertyMap(session, description, out_lyrics);
  });
}

tlb_status_t tlb_session_write_lyrics(tlb_session_t *session,
                                      const char *text,
                                      const char *language,
                                      const char *description,
                                      uint8_t id3v2_version)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || text == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb_status_t mpeg_status = WriteLyricsToMpeg(
      session,
      text,
      language,
      description,
      id3v2_version);
    if(mpeg_status == TLB_STATUS_OK) {
      return TLB_STATUS_OK;
    }
    if(mpeg_status != TLB_STATUS_UNSUPPORTED_FORMAT) {
      return mpeg_status;
    }

    return WriteLyricsToPropertyMap(session, text, description);
  });
}

tlb_status_t tlb_session_clear_lyrics(tlb_session_t *session,
                                      const char *language,
                                      const char *description,
                                      uint8_t id3v2_version)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session)) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb_status_t mpeg_status = ClearLyricsFromMpeg(
      session,
      language,
      description,
      id3v2_version);
    if(mpeg_status == TLB_STATUS_OK) {
      return TLB_STATUS_OK;
    }
    if(mpeg_status != TLB_STATUS_UNSUPPORTED_FORMAT) {
      return mpeg_status;
    }

    return ClearLyricsFromPropertyMap(session, description);
  });
}

tlb_status_t tlb_session_read_basic_tags(tlb_session_t *session, tlb_basic_tags_t *out_tags)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_tags == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb::bridge::FreeBasicTagsMembers(out_tags);

    TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
    if(file_ref == nullptr || file_ref->isNull()) {
      return TLB_STATUS_IO_ERROR;
    }

    Tag *tag = file_ref->tag();
    if(tag == nullptr) {
      return TLB_STATUS_TAGLIB_ERROR;
    }

    out_tags->title = tlb::bridge::DupUtf8StringOrNull(tag->title());
    out_tags->artist = tlb::bridge::DupUtf8StringOrNull(tag->artist());
    out_tags->album = tlb::bridge::DupUtf8StringOrNull(tag->album());
    out_tags->comment = tlb::bridge::DupUtf8StringOrNull(tag->comment());
    out_tags->genre = tlb::bridge::DupUtf8StringOrNull(tag->genre());
    out_tags->year = tag->year();
    out_tags->track = tag->track();

    tlb_status_t lyrics_status =
      tlb_session_read_lyrics(session, nullptr, nullptr, &out_tags->lyrics);
    if(lyrics_status != TLB_STATUS_OK && lyrics_status != TLB_STATUS_NOT_FOUND) {
      tlb::bridge::FreeBasicTagsMembers(out_tags);
      return lyrics_status;
    }

    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_write_basic_tags(tlb_session_t *session,
                                          const tlb_basic_tags_t *tags,
                                          uint8_t id3v2_version)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || tags == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }
    TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
    if(file_ref == nullptr || file_ref->isNull()) {
      return TLB_STATUS_IO_ERROR;
    }
    Tag *tag = file_ref->tag();
    if(tag == nullptr) {
      return TLB_STATUS_TAGLIB_ERROR;
    }
    TagLib::MPEG::File *mpeg_file = tlb::bridge::SessionMpegFile(session);
    TagLib::ID3v2::Version parsed_version = TagLib::ID3v2::v4;
    if(mpeg_file != nullptr &&
       !tlb::bridge::ParseId3v2Version(id3v2_version, &parsed_version)) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }
    if(tags->title != nullptr) tag->setTitle(tlb::bridge::ToTagString(tags->title));
    if(tags->artist != nullptr) tag->setArtist(tlb::bridge::ToTagString(tags->artist));
    if(tags->album != nullptr) tag->setAlbum(tlb::bridge::ToTagString(tags->album));
    if(tags->comment != nullptr) tag->setComment(tlb::bridge::ToTagString(tags->comment));
    if(tags->genre != nullptr) tag->setGenre(tlb::bridge::ToTagString(tags->genre));
    tag->setYear(tags->year);
    tag->setTrack(tags->track);
    if(mpeg_file != nullptr) {
      if(tags->lyrics != nullptr) {
        const tlb_status_t lyrics_status = ApplyLyricsToMpegWithoutSave(
          mpeg_file, tags->lyrics, "eng", "LYRICS");
        if(lyrics_status != TLB_STATUS_OK) return lyrics_status;
      }
      if(!mpeg_file->save(TagLib::MPEG::File::AllTags,
                          File::StripOthers,
                          parsed_version,
                          File::Duplicate)) {
        return TLB_STATUS_IO_ERROR;
      }
      return TLB_STATUS_OK;
    }
    const tlb_status_t lyrics_status = ApplyLyricsToPropertyMapWithoutSave(
      file_ref, tags->lyrics, "LYRICS");
    if(lyrics_status != TLB_STATUS_OK) return lyrics_status;
    if(!file_ref->save()) {
      return TLB_STATUS_IO_ERROR;
    }
    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_read_audio_properties(tlb_session_t *session,
                                               tlb_audio_properties_t *out_properties)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_properties == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb::bridge::ZeroStruct(out_properties);

    TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
    if(file_ref == nullptr || file_ref->isNull()) {
      return TLB_STATUS_IO_ERROR;
    }

    AudioProperties *properties = file_ref->audioProperties();
    if(properties == nullptr) {
      return TLB_STATUS_NOT_FOUND;
    }

    out_properties->length_seconds = properties->lengthInSeconds();
    out_properties->bitrate_kbps = properties->bitrate();
    out_properties->sample_rate = properties->sampleRate();
    out_properties->channels = properties->channels();
    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_read_property_map(tlb_session_t *session,
                                           tlb_property_map_t *out_map)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_map == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb::bridge::FreePropertyMapMembers(out_map);

    TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
    if(file_ref == nullptr || file_ref->isNull()) {
      return TLB_STATUS_IO_ERROR;
    }

    const PropertyMap map = file_ref->properties();
    if(map.isEmpty()) {
      return TLB_STATUS_OK;
    }

    out_map->items = static_cast<tlb_property_item_t *>(
      std::calloc(map.size(), sizeof(tlb_property_item_t)));
    if(out_map->items == nullptr) {
      return TLB_STATUS_OUT_OF_MEMORY;
    }
    out_map->item_count = map.size();

    uint32_t index = 0;
    for(const auto &[key, values] : map) {
      tlb_property_item_t &item = out_map->items[index];

      item.key = tlb::bridge::DupUtf8String(key);
      if(item.key == nullptr) {
        tlb::bridge::FreePropertyMapMembers(out_map);
        return TLB_STATUS_OUT_OF_MEMORY;
      }

      item.value_count = values.size();
      if(item.value_count > 0) {
        if(!CopyStringArray(values, &item.values)) {
          tlb::bridge::FreePropertyMapMembers(out_map);
          return TLB_STATUS_OUT_OF_MEMORY;
        }
      }
      ++index;
    }

    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_write_property_map(tlb_session_t *session, const tlb_property_map_t *map)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || map == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
    if(file_ref == nullptr || file_ref->isNull()) {
      return TLB_STATUS_IO_ERROR;
    }

    PropertyMap property_map;
    for(uint32_t i = 0; i < map->item_count; ++i) {
      const tlb_property_item_t &item = map->items[i];
      if(item.key == nullptr) {
        continue;
      }

      StringList values;
      for(uint32_t j = 0; j < item.value_count; ++j) {
        if(item.values == nullptr || item.values[j] == nullptr) {
          continue;
        }
        values.append(tlb::bridge::ToTagString(item.values[j]));
      }

      if(!property_map.replace(tlb::bridge::ToTagString(item.key), values)) {
        return TLB_STATUS_INVALID_ARGUMENT;
      }
    }

    file_ref->setProperties(property_map);
    if(!file_ref->save()) {
      return TLB_STATUS_IO_ERROR;
    }
    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_read_pictures(tlb_session_t *session, tlb_picture_list_t *out_pictures)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || out_pictures == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    tlb::bridge::FreePictureListMembers(out_pictures);

    TagLib::FileRef *file_ref = tlb::bridge::SessionFileRef(session);
    if(file_ref == nullptr || file_ref->isNull()) {
      return TLB_STATUS_IO_ERROR;
    }

    const List<VariantMap> pictures = file_ref->complexProperties("PICTURE");
    if(pictures.isEmpty()) {
      return TLB_STATUS_OK;
    }

    out_pictures->items = static_cast<tlb_picture_item_t *>(
      std::calloc(pictures.size(), sizeof(tlb_picture_item_t)));
    if(out_pictures->items == nullptr) {
      return TLB_STATUS_OUT_OF_MEMORY;
    }
    out_pictures->item_count = pictures.size();

    for(uint32_t i = 0; i < out_pictures->item_count; ++i) {
      if(!FillPictureItemFromVariantMap(pictures[i], &out_pictures->items[i])) {
        tlb::bridge::FreePictureListMembers(out_pictures);
        return TLB_STATUS_OUT_OF_MEMORY;
      }
    }

    return TLB_STATUS_OK;
  });
}

tlb_status_t tlb_session_write_pictures(tlb_session_t *session,
                                        const tlb_picture_list_t *pictures,
                                        uint8_t clear_existing)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || pictures == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    List<VariantMap> mapped_pictures;
    for(uint32_t i = 0; i < pictures->item_count; ++i) {
      mapped_pictures.append(BuildVariantMapFromPictureItem(pictures->items[i]));
    }
    return WritePictureMaps(session, mapped_pictures, clear_existing);
  });
}

tlb_status_t tlb_session_write_picture_files(tlb_session_t *session,
                                             const tlb_picture_file_list_t *pictures,
                                             uint8_t clear_existing)
{
  return tlb::bridge::SafeCall([&]() -> tlb_status_t {
    if(!tlb::bridge::IsValidSession(session) || pictures == nullptr) {
      return TLB_STATUS_INVALID_ARGUMENT;
    }

    List<VariantMap> mapped_pictures;
    for(uint32_t i = 0; i < pictures->item_count; ++i) {
      VariantMap map;
      const tlb_status_t status =
        BuildVariantMapFromPictureFileItem(pictures->items[i], &map);
      if(status != TLB_STATUS_OK) {
        return status;
      }
      mapped_pictures.append(map);
    }
    return WritePictureMaps(session, mapped_pictures, clear_existing);
  });
}

}  // extern "C"
