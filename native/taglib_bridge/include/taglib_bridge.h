// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

#ifndef TLB_TAGLIB_BRIDGE_H
#define TLB_TAGLIB_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
#if defined(_WIN32) || defined(_WIN64)
#if defined(TAGLIB_BRIDGE_BUILDING)
#define TLB_EXPORT __declspec(dllexport)
#else
#define TLB_EXPORT __declspec(dllimport)
#endif
#elif defined(__GNUC__) && (__GNUC__ >= 4)
#define TLB_EXPORT __attribute__((visibility("default")))
#else
#define TLB_EXPORT
#endif
#define TLB_API_VERSION_VALUE 4u

typedef enum tlb_status_t {
  TLB_STATUS_OK = 0,
  TLB_STATUS_INVALID_ARGUMENT = 1,
  TLB_STATUS_IO_ERROR = 2,
  TLB_STATUS_UNSUPPORTED_FORMAT = 3,
  TLB_STATUS_NOT_FOUND = 4,
  TLB_STATUS_TAGLIB_ERROR = 5,
  TLB_STATUS_OUT_OF_MEMORY = 6,
  TLB_STATUS_INTERNAL_ERROR = 7
} tlb_status_t;

typedef enum tlb_id3v2_version_t {
  TLB_ID3V2_VERSION_23 = 3,
  TLB_ID3V2_VERSION_24 = 4
} tlb_id3v2_version_t;

typedef enum tlb_sylt_timestamp_format_t {
  TLB_SYLT_TIMESTAMP_UNKNOWN = 0,
  TLB_SYLT_TIMESTAMP_MPEG_FRAMES = 1,
  TLB_SYLT_TIMESTAMP_MILLISECONDS = 2
} tlb_sylt_timestamp_format_t;

typedef enum tlb_sylt_type_t {
  TLB_SYLT_TYPE_OTHER = 0,
  TLB_SYLT_TYPE_LYRICS = 1,
  TLB_SYLT_TYPE_TEXT_TRANSCRIPTION = 2,
  TLB_SYLT_TYPE_MOVEMENT = 3,
  TLB_SYLT_TYPE_EVENTS = 4,
  TLB_SYLT_TYPE_CHORD = 5,
  TLB_SYLT_TYPE_TRIVIA = 6,
  TLB_SYLT_TYPE_WEBPAGE_URLS = 7,
  TLB_SYLT_TYPE_IMAGE_URLS = 8
} tlb_sylt_type_t;

typedef enum tlb_sylt_merge_mode_t {
  TLB_SYLT_MERGE_REPLACE_BY_KEY = 0,
  TLB_SYLT_MERGE_APPEND = 1,
  TLB_SYLT_MERGE_REPLACE_ALL = 2
} tlb_sylt_merge_mode_t;

typedef enum tlb_text_source_t {
  TLB_TEXT_SOURCE_ID3V1 = 1,
  TLB_TEXT_SOURCE_RIFF_INFO = 2,
  TLB_TEXT_SOURCE_ID3V2_LATIN1 = 3
} tlb_text_source_t;

typedef struct tlb_session_t tlb_session_t;

typedef struct tlb_audio_properties_t {
  int32_t length_seconds;
  int32_t bitrate_kbps;
  int32_t sample_rate;
  int32_t channels;
} tlb_audio_properties_t;

typedef struct tlb_basic_tags_t {
  char *title;
  char *artist;
  char *album;
  char *comment;
  char *genre;
  char *lyrics;
  uint32_t year;
  uint32_t track;
} tlb_basic_tags_t;

typedef struct tlb_property_item_t {
  char *key;
  char **values;
  uint32_t value_count;
} tlb_property_item_t;

typedef struct tlb_property_map_t {
  tlb_property_item_t *items;
  uint32_t item_count;
} tlb_property_map_t;

typedef struct tlb_picture_item_t {
  char *mime_type;
  char *description;
  char *picture_type;
  uint8_t *data;
  uint32_t data_length;
} tlb_picture_item_t;

typedef struct tlb_picture_list_t {
  tlb_picture_item_t *items;
  uint32_t item_count;
} tlb_picture_list_t;

typedef struct tlb_picture_file_item_t {
  char *path;
  char *mime_type;
  char *description;
  char *picture_type;
} tlb_picture_file_item_t;

typedef struct tlb_picture_file_list_t {
  tlb_picture_file_item_t *items;
  uint32_t item_count;
} tlb_picture_file_list_t;

typedef struct tlb_sylt_entry_t {
  uint32_t time;
  char *text;
} tlb_sylt_entry_t;

typedef struct tlb_sylt_track_t {
  char language[4];
  char *description;
  uint8_t type;
  uint8_t timestamp_format;
  tlb_sylt_entry_t *entries;
  uint32_t entry_count;
} tlb_sylt_track_t;

typedef struct tlb_sylt_track_list_t {
  tlb_sylt_track_t *tracks;
  uint32_t track_count;
} tlb_sylt_track_list_t;

typedef struct tlb_sylt_filter_t {
  const char *language;
  const char *description;
  int32_t type;
} tlb_sylt_filter_t;

typedef struct tlb_text_issue_t {
  tlb_text_source_t source;
  char *field_path;
  char *frame_id;
  char *language;
  char *description;
  uint8_t *raw_bytes;
  uint32_t raw_bytes_length;
  char *baseline_decoded;
} tlb_text_issue_t;

typedef struct tlb_text_issue_list_t {
  tlb_text_issue_t *issues;
  uint32_t issue_count;
} tlb_text_issue_list_t;

typedef struct tlb_session_capabilities_t {
  uint8_t plain_lyrics_writable;
  uint8_t synced_lyrics_writable;
  uint8_t mp3_id3_save_supported;
  uint8_t uslt;
  uint8_t lyrics;
  uint8_t mp4_lyr;
  uint8_t wm_lyrics;
  uint8_t hint_based;
} tlb_session_capabilities_t;

typedef struct tlb_abi_field_t {
  const char *struct_name;
  const char *field_name;
  uint32_t offset;
  uint32_t size;
} tlb_abi_field_t;

TLB_EXPORT uint32_t tlb_api_version(void);
TLB_EXPORT uint32_t tlb_abi_field_count(void);
TLB_EXPORT const tlb_abi_field_t *tlb_abi_fields(void);
TLB_EXPORT const char *tlb_status_message(tlb_status_t status);

TLB_EXPORT void tlb_free_string(char *value);
TLB_EXPORT void tlb_free_bytes(uint8_t *value);
TLB_EXPORT void tlb_free_basic_tags(tlb_basic_tags_t *value);
TLB_EXPORT void tlb_free_property_map(tlb_property_map_t *value);
TLB_EXPORT void tlb_free_picture_list(tlb_picture_list_t *value);
TLB_EXPORT void tlb_free_sylt_track_list(tlb_sylt_track_list_t *value);
TLB_EXPORT void tlb_free_text_issue_list(tlb_text_issue_list_t *value);

TLB_EXPORT tlb_status_t tlb_session_open_from_bytes(const uint8_t *bytes,
                                                    uint32_t length,
                                                    const char *name_hint,
                                                    tlb_session_t **out_session);
TLB_EXPORT tlb_status_t tlb_session_open_from_path(const char *path,
                                                   tlb_session_t **out_session);
TLB_EXPORT tlb_status_t tlb_session_open_from_fd(int32_t file_descriptor,
                                                 const char *name_hint,
                                                 tlb_session_t **out_session);
TLB_EXPORT tlb_status_t tlb_session_close(tlb_session_t **session);
TLB_EXPORT void tlb_session_finalize(tlb_session_t *session);
TLB_EXPORT tlb_status_t tlb_session_export_bytes(const tlb_session_t *session,
                                                 uint8_t **out_bytes,
                                                 uint32_t *out_length);

TLB_EXPORT tlb_status_t tlb_session_read_basic_tags(tlb_session_t *session,
                                                    tlb_basic_tags_t *out_tags);
TLB_EXPORT tlb_status_t tlb_session_write_basic_tags(tlb_session_t *session,
                                                     const tlb_basic_tags_t *tags,
                                                     uint8_t id3v2_version);
TLB_EXPORT tlb_status_t tlb_session_read_audio_properties(
  tlb_session_t *session,
  tlb_audio_properties_t *out_properties);
TLB_EXPORT tlb_status_t tlb_session_probe_capabilities(
  tlb_session_t *session,
  tlb_session_capabilities_t *out_capabilities);

TLB_EXPORT tlb_status_t tlb_session_read_property_map(tlb_session_t *session,
                                                      tlb_property_map_t *out_map);
TLB_EXPORT tlb_status_t tlb_session_write_property_map(tlb_session_t *session,
                                                       const tlb_property_map_t *map);

TLB_EXPORT tlb_status_t tlb_session_read_pictures(tlb_session_t *session,
                                                  tlb_picture_list_t *out_pictures);
TLB_EXPORT tlb_status_t tlb_session_write_pictures(tlb_session_t *session,
                                                   const tlb_picture_list_t *pictures,
                                                   uint8_t clear_existing);
TLB_EXPORT tlb_status_t tlb_session_write_picture_files(
  tlb_session_t *session,
  const tlb_picture_file_list_t *pictures,
  uint8_t clear_existing);

TLB_EXPORT tlb_status_t tlb_session_read_lyrics(tlb_session_t *session,
                                                const char *language,
                                                const char *description,
                                                char **out_lyrics);
TLB_EXPORT tlb_status_t tlb_session_write_lyrics(tlb_session_t *session,
                                                 const char *text,
                                                 const char *language,
                                                 const char *description,
                                                 uint8_t id3v2_version);
TLB_EXPORT tlb_status_t tlb_session_clear_lyrics(tlb_session_t *session,
                                                 const char *language,
                                                 const char *description,
                                                 uint8_t id3v2_version);

TLB_EXPORT tlb_status_t tlb_session_mp3_save_with_id3v2_version(tlb_session_t *session,
                                                                 uint8_t version);

TLB_EXPORT tlb_status_t tlb_session_mp3_sylt_read(tlb_session_t *session,
                                                  tlb_sylt_track_list_t *out_tracks);
TLB_EXPORT tlb_status_t tlb_session_mp3_sylt_write(tlb_session_t *session,
                                                   const tlb_sylt_track_t *tracks,
                                                   uint32_t track_count,
                                                   tlb_sylt_merge_mode_t merge_mode,
                                                   uint8_t id3v2_version);
TLB_EXPORT tlb_status_t tlb_session_mp3_sylt_clear(tlb_session_t *session,
                                                   const tlb_sylt_filter_t *filter,
                                                   uint8_t id3v2_version);

TLB_EXPORT tlb_status_t tlb_session_text_issues_scan(tlb_session_t *session,
                                                     tlb_text_issue_list_t *out_issues);

#ifdef __cplusplus
}
#endif

#endif
