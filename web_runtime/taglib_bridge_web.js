// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/* eslint-disable no-bitwise */

(function initTaglibBridgeWeb(globalScope) {
  const STATUS_OK = 0;
  const STATUS_NOT_FOUND = 4;

  const sessionFinalizer = typeof FinalizationRegistry === "function"
    ? new FinalizationRegistry((state) => {
        // 页面仍存活时兜底释放遗忘 close() 的 WASM 会话。
        state.finalizeSession(state.session);
      })
    : null;

  const SIZE_BASIC_TAGS = 32;
  const SIZE_AUDIO_PROPERTIES = 16;
  const SIZE_SESSION_CAPABILITIES = 8;
  const SIZE_PROPERTY_ITEM = 12;
  const SIZE_PROPERTY_MAP = 8;
  const SIZE_PICTURE_ITEM = 20;
  const SIZE_PICTURE_LIST = 8;
  const SIZE_SYLT_ENTRY = 8;
  const SIZE_SYLT_TRACK = 20;
  const SIZE_SYLT_TRACK_LIST = 8;
  const SIZE_SYLT_FILTER = 12;
  const SIZE_TEXT_ISSUE = 32;
  const SIZE_TEXT_ISSUE_LIST = 8;
  const SIZE_POINTER = 4;
  const EXPECTED_API_VERSION = 4;
  const EXPECTED_ABI_FIELDS = {
    "tlb_audio_properties_t.length_seconds": [0, 4],
    "tlb_audio_properties_t.bitrate_kbps": [4, 4],
    "tlb_audio_properties_t.sample_rate": [8, 4],
    "tlb_audio_properties_t.channels": [12, 4],
    "tlb_basic_tags_t.title": [0, 4],
    "tlb_basic_tags_t.artist": [4, 4],
    "tlb_basic_tags_t.album": [8, 4],
    "tlb_basic_tags_t.comment": [12, 4],
    "tlb_basic_tags_t.genre": [16, 4],
    "tlb_basic_tags_t.lyrics": [20, 4],
    "tlb_basic_tags_t.year": [24, 4],
    "tlb_basic_tags_t.track": [28, 4],
    "tlb_session_capabilities_t.plain_lyrics_writable": [0, 1],
    "tlb_session_capabilities_t.synced_lyrics_writable": [1, 1],
    "tlb_session_capabilities_t.mp3_id3_save_supported": [2, 1],
    "tlb_session_capabilities_t.uslt": [3, 1],
    "tlb_session_capabilities_t.lyrics": [4, 1],
    "tlb_session_capabilities_t.mp4_lyr": [5, 1],
    "tlb_session_capabilities_t.wm_lyrics": [6, 1],
    "tlb_session_capabilities_t.hint_based": [7, 1],
    "tlb_property_item_t.key": [0, 4],
    "tlb_property_item_t.values": [4, 4],
    "tlb_property_item_t.value_count": [8, 4],
    "tlb_property_map_t.items": [0, 4],
    "tlb_property_map_t.item_count": [4, 4],
    "tlb_picture_item_t.mime_type": [0, 4],
    "tlb_picture_item_t.description": [4, 4],
    "tlb_picture_item_t.picture_type": [8, 4],
    "tlb_picture_item_t.data": [12, 4],
    "tlb_picture_item_t.data_length": [16, 4],
    "tlb_picture_list_t.items": [0, 4],
    "tlb_picture_list_t.item_count": [4, 4],
    "tlb_sylt_entry_t.time": [0, 4],
    "tlb_sylt_entry_t.text": [4, 4],
    "tlb_sylt_track_t.language": [0, 4],
    "tlb_sylt_track_t.description": [4, 4],
    "tlb_sylt_track_t.type": [8, 1],
    "tlb_sylt_track_t.timestamp_format": [9, 1],
    "tlb_sylt_track_t.entries": [12, 4],
    "tlb_sylt_track_t.entry_count": [16, 4],
    "tlb_sylt_track_list_t.tracks": [0, 4],
    "tlb_sylt_track_list_t.track_count": [4, 4],
    "tlb_sylt_filter_t.language": [0, 4],
    "tlb_sylt_filter_t.description": [4, 4],
    "tlb_sylt_filter_t.type": [8, 4],
    "tlb_text_issue_t.source": [0, 4],
    "tlb_text_issue_t.field_path": [4, 4],
    "tlb_text_issue_t.frame_id": [8, 4],
    "tlb_text_issue_t.language": [12, 4],
    "tlb_text_issue_t.description": [16, 4],
    "tlb_text_issue_t.raw_bytes": [20, 4],
    "tlb_text_issue_t.raw_bytes_length": [24, 4],
    "tlb_text_issue_t.baseline_decoded": [28, 4],
    "tlb_text_issue_list_t.issues": [0, 4],
    "tlb_text_issue_list_t.issue_count": [4, 4],
  };

  function asU32(value) {
    return value >>> 0;
  }

  function getPtr(module, ptr) {
    return asU32(module.getValue(ptr, "*"));
  }

  function setPtr(module, ptr, value) {
    module.setValue(ptr, asU32(value), "*");
  }

  function getI32(module, ptr) {
    return module.getValue(ptr, "i32") | 0;
  }

  function setI32(module, ptr, value) {
    module.setValue(ptr, value | 0, "i32");
  }

  function getU8(module, ptr) {
    return module.getValue(ptr, "i8") & 0xff;
  }

  function setU8(module, ptr, value) {
    module.setValue(ptr, value & 0xff, "i8");
  }

  function utf8Encode(module, value, allocations) {
    if (value === null || value === undefined) {
      return 0;
    }
    const text = String(value);
    const size = module.lengthBytesUTF8(text) + 1;
    const ptr = module._malloc(size);
    module.stringToUTF8(text, ptr, size);
    if (allocations) allocations.push(ptr);
    return ptr;
  }

  function readCString(module, ptr) {
    if (!ptr) {
      return null;
    }
    return module.UTF8ToString(ptr);
  }


  function verifyBridgeAbi(module, fns) {
    const actualVersion = fns.apiVersion();
    if (actualVersion !== EXPECTED_API_VERSION) {
      throw new Error(`taglib bridge ABI version mismatch: expected ${EXPECTED_API_VERSION}, actual ${actualVersion}`);
    }

    const count = fns.abiFieldCount();
    const fieldsPtr = fns.abiFields();
    const seen = new Set();
    for (let i = 0; i < count; i += 1) {
      const rowPtr = fieldsPtr + i * 16;
      const structName = readCString(module, getPtr(module, rowPtr));
      const fieldName = readCString(module, getPtr(module, rowPtr + 4));
      const offset = getI32(module, rowPtr + 8) >>> 0;
      const size = getI32(module, rowPtr + 12) >>> 0;
      const key = `${structName}.${fieldName}`;
      const expected = EXPECTED_ABI_FIELDS[key];
      if (!expected) {
        continue;
      }
      seen.add(key);
      if (offset !== expected[0] || size !== expected[1]) {
        throw new Error(`taglib bridge ABI field mismatch for ${key}: expected ${expected[0]}/${expected[1]}, actual ${offset}/${size}`);
      }
    }

    for (const key of Object.keys(EXPECTED_ABI_FIELDS)) {
      if (!seen.has(key)) {
        throw new Error(`taglib bridge ABI field missing: ${key}`);
      }
    }
  }
  function throwIfStatus(statusMessage, status) {
    if (status === STATUS_OK) {
      return;
    }
    const message = statusMessage(status) || `taglib bridge status=${status}`;
    const error = new Error(message);
    error.status = status;
    throw error;
  }

  function readBytes(module, ptr, length) {
    const out = new Uint8Array(length);
    for (let i = 0; i < length; i += 1) {
      out[i] = getU8(module, ptr + i);
    }
    return out;
  }

  function writeBytes(module, ptr, bytes) {
    for (let i = 0; i < bytes.length; i += 1) {
      setU8(module, ptr + i, bytes[i]);
    }
  }

  function allocInputBytes(module, bytes, allocations) {
    const typed = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
    if (typed.length === 0) {
      return { ptr: 0, length: 0 };
    }
    const ptr = module._malloc(typed.length);
    writeBytes(module, ptr, typed);
    allocations.push(ptr);
    return { ptr, length: typed.length };
  }

  function allocZeroed(module, size, allocations) {
    const ptr = module._malloc(size);
    for (let i = 0; i < size; i += 1) {
      setU8(module, ptr + i, 0);
    }
    if (allocations) {
      allocations.push(ptr);
    }
    return ptr;
  }

  function writeBasicTagsStruct(module, structPtr, tags, allocations) {
    setPtr(module, structPtr + 0, utf8Encode(module, tags.title, allocations));
    setPtr(module, structPtr + 4, utf8Encode(module, tags.artist, allocations));
    setPtr(module, structPtr + 8, utf8Encode(module, tags.album, allocations));
    setPtr(module, structPtr + 12, utf8Encode(module, tags.comment, allocations));
    setPtr(module, structPtr + 16, utf8Encode(module, tags.genre, allocations));
    setPtr(module, structPtr + 20, utf8Encode(module, tags.lyrics, allocations));
    setI32(module, structPtr + 24, asU32(tags.year || 0));
    setI32(module, structPtr + 28, asU32(tags.track || 0));
  }

  function parseBasicTags(module, structPtr) {
    return {
      title: readCString(module, getPtr(module, structPtr + 0)),
      artist: readCString(module, getPtr(module, structPtr + 4)),
      album: readCString(module, getPtr(module, structPtr + 8)),
      comment: readCString(module, getPtr(module, structPtr + 12)),
      genre: readCString(module, getPtr(module, structPtr + 16)),
      lyrics: readCString(module, getPtr(module, structPtr + 20)),
      year: asU32(getI32(module, structPtr + 24)),
      track: asU32(getI32(module, structPtr + 28)),
    };
  }

  function parseAudioProperties(module, structPtr) {
    return {
      lengthSeconds: getI32(module, structPtr + 0),
      bitrateKbps: getI32(module, structPtr + 4),
      sampleRate: getI32(module, structPtr + 8),
      channels: getI32(module, structPtr + 12),
    };
  }

  function parseSessionCapabilities(module, structPtr) {
    return {
      plainLyricsWritable: getU8(module, structPtr + 0) !== 0,
      syncedLyricsWritable: getU8(module, structPtr + 1) !== 0,
      mp3Id3SaveSupported: getU8(module, structPtr + 2) !== 0,
      uslt: getU8(module, structPtr + 3) !== 0,
      lyrics: getU8(module, structPtr + 4) !== 0,
      mp4Lyr: getU8(module, structPtr + 5) !== 0,
      wmLyrics: getU8(module, structPtr + 6) !== 0,
      hintBased: getU8(module, structPtr + 7) !== 0,
    };
  }

  function parsePropertyMap(module, mapPtr) {
    const itemsPtr = getPtr(module, mapPtr + 0);
    const itemCount = asU32(getI32(module, mapPtr + 4));
    const items = [];
    for (let i = 0; i < itemCount; i += 1) {
      const base = itemsPtr + (i * SIZE_PROPERTY_ITEM);
      const key = readCString(module, getPtr(module, base + 0)) || "";
      const valuesPtr = getPtr(module, base + 4);
      const valueCount = asU32(getI32(module, base + 8));
      const values = [];
      for (let j = 0; j < valueCount; j += 1) {
        const valuePtr = getPtr(module, valuesPtr + (j * SIZE_POINTER));
        values.push(readCString(module, valuePtr) || "");
      }
      items.push({ key, values });
    }
    return { items };
  }

  function allocPropertyMap(module, map, allocations) {
    const entries = Array.isArray(map && map.items) ? map.items : [];
    const mapPtr = module._malloc(SIZE_PROPERTY_MAP);
    allocations.push(mapPtr);
    setPtr(module, mapPtr + 0, 0);
    setI32(module, mapPtr + 4, entries.length);

    if (entries.length === 0) {
      return mapPtr;
    }

    const itemsPtr = module._malloc(entries.length * SIZE_PROPERTY_ITEM);
    allocations.push(itemsPtr);
    setPtr(module, mapPtr + 0, itemsPtr);

    for (let i = 0; i < entries.length; i += 1) {
      const item = entries[i] || {};
      const base = itemsPtr + (i * SIZE_PROPERTY_ITEM);
      setPtr(module, base + 0, utf8Encode(module, item.key || "", allocations));

      const values = Array.isArray(item.values) ? item.values : [];
      setI32(module, base + 8, values.length);
      if (values.length === 0) {
        setPtr(module, base + 4, 0);
        continue;
      }

      const valuesPtr = module._malloc(values.length * SIZE_POINTER);
      allocations.push(valuesPtr);
      setPtr(module, base + 4, valuesPtr);

      for (let j = 0; j < values.length; j += 1) {
        const valuePtr = utf8Encode(module, values[j] || "", allocations);
        setPtr(module, valuesPtr + (j * SIZE_POINTER), valuePtr);
      }
    }
    return mapPtr;
  }

  function parsePictures(module, listPtr) {
    const itemsPtr = getPtr(module, listPtr + 0);
    const itemCount = asU32(getI32(module, listPtr + 4));
    const items = [];
    for (let i = 0; i < itemCount; i += 1) {
      const base = itemsPtr + (i * SIZE_PICTURE_ITEM);
      const mimeType = readCString(module, getPtr(module, base + 0));
      const description = readCString(module, getPtr(module, base + 4));
      const pictureType = readCString(module, getPtr(module, base + 8));
      const dataPtr = getPtr(module, base + 12);
      const dataLength = asU32(getI32(module, base + 16));
      items.push({
        mimeType,
        description,
        pictureType,
        data: dataPtr && dataLength ? readBytes(module, dataPtr, dataLength) : new Uint8Array(0),
      });
    }
    return { items };
  }

  function allocPictures(module, pictures, allocations) {
    const items = Array.isArray(pictures && pictures.items)
      ? pictures.items
      : (Array.isArray(pictures) ? pictures : []);
    const listPtr = module._malloc(SIZE_PICTURE_LIST);
    allocations.push(listPtr);
    setPtr(module, listPtr + 0, 0);
    setI32(module, listPtr + 4, items.length);

    if (items.length === 0) {
      return listPtr;
    }

    const itemsPtr = module._malloc(items.length * SIZE_PICTURE_ITEM);
    allocations.push(itemsPtr);
    setPtr(module, listPtr + 0, itemsPtr);

    for (let i = 0; i < items.length; i += 1) {
      const item = items[i] || {};
      const base = itemsPtr + (i * SIZE_PICTURE_ITEM);
      setPtr(module, base + 0, utf8Encode(module, item.mimeType, allocations));
      setPtr(module, base + 4, utf8Encode(module, item.description, allocations));
      setPtr(module, base + 8, utf8Encode(module, item.pictureType, allocations));

      const bytes = item.data instanceof Uint8Array
        ? item.data
        : new Uint8Array(item.data || []);
      if (bytes.length === 0) {
        setPtr(module, base + 12, 0);
        setI32(module, base + 16, 0);
        continue;
      }
      const dataPtr = module._malloc(bytes.length);
      allocations.push(dataPtr);
      writeBytes(module, dataPtr, bytes);
      setPtr(module, base + 12, dataPtr);
      setI32(module, base + 16, bytes.length);
    }

    return listPtr;
  }

  function parseSyltTracks(module, trackListPtr) {
    const tracksPtr = getPtr(module, trackListPtr + 0);
    const trackCount = asU32(getI32(module, trackListPtr + 4));
    const tracks = [];
    for (let i = 0; i < trackCount; i += 1) {
      const base = tracksPtr + (i * SIZE_SYLT_TRACK);
      const languageBytes = [getU8(module, base), getU8(module, base + 1), getU8(module, base + 2)]
        .filter((v) => v !== 0);
      const language = new TextDecoder().decode(new Uint8Array(languageBytes));
      const description = readCString(module, getPtr(module, base + 4)) || "";
      const type = getU8(module, base + 8);
      const timestampFormat = getU8(module, base + 9);
      const entriesPtr = getPtr(module, base + 12);
      const entryCount = asU32(getI32(module, base + 16));

      const entries = [];
      for (let j = 0; j < entryCount; j += 1) {
        const eBase = entriesPtr + (j * SIZE_SYLT_ENTRY);
        entries.push({
          time: asU32(getI32(module, eBase + 0)),
          text: readCString(module, getPtr(module, eBase + 4)) || "",
        });
      }

      tracks.push({ language, description, type, timestampFormat, entries });
    }
    return tracks;
  }

  function allocSyltTracks(module, tracks, allocations) {
    const rows = Array.isArray(tracks) ? tracks : [];
    if (rows.length === 0) {
      return 0;
    }

    const encoder = new TextEncoder();
    const tracksPtr = module._malloc(rows.length * SIZE_SYLT_TRACK);
    allocations.push(tracksPtr);
    for (let i = 0; i < rows.length * SIZE_SYLT_TRACK; i += 1) {
      setU8(module, tracksPtr + i, 0);
    }

    for (let i = 0; i < rows.length; i += 1) {
      const track = rows[i] || {};
      const base = tracksPtr + (i * SIZE_SYLT_TRACK);
      const language = encoder.encode(String(track.language || "eng").slice(0, 3));
      setU8(module, base + 0, language[0] || 0);
      setU8(module, base + 1, language[1] || 0);
      setU8(module, base + 2, language[2] || 0);
      setPtr(module, base + 4, utf8Encode(module, track.description || "", allocations));
      setU8(module, base + 8, asU32(track.type || 0));
      setU8(module, base + 9, asU32(track.timestampFormat || 0));

      const entries = Array.isArray(track.entries) ? track.entries : [];
      setI32(module, base + 16, entries.length);
      if (entries.length === 0) {
        setPtr(module, base + 12, 0);
        continue;
      }

      const entriesPtr = module._malloc(entries.length * SIZE_SYLT_ENTRY);
      allocations.push(entriesPtr);
      setPtr(module, base + 12, entriesPtr);
      for (let j = 0; j < entries.length; j += 1) {
        const entry = entries[j] || {};
        const eBase = entriesPtr + (j * SIZE_SYLT_ENTRY);
        setI32(module, eBase + 0, asU32(entry.time || 0));
        setPtr(module, eBase + 4, utf8Encode(module, entry.text || "", allocations));
      }
    }
    return tracksPtr;
  }

  function parseTextIssues(module, issueListPtr) {
    const issuesPtr = getPtr(module, issueListPtr + 0);
    const issueCount = asU32(getI32(module, issueListPtr + 4));
    const issues = [];
    for (let i = 0; i < issueCount; i += 1) {
      const base = issuesPtr + (i * SIZE_TEXT_ISSUE);
      const rawBytesPtr = getPtr(module, base + 20);
      const rawBytesLength = asU32(getI32(module, base + 24));
      issues.push({
        source: getI32(module, base + 0),
        fieldPath: readCString(module, getPtr(module, base + 4)),
        frameId: readCString(module, getPtr(module, base + 8)),
        language: readCString(module, getPtr(module, base + 12)),
        description: readCString(module, getPtr(module, base + 16)),
        rawBytes: rawBytesPtr && rawBytesLength
          ? Array.from(readBytes(module, rawBytesPtr, rawBytesLength))
          : [],
        baselineDecoded: readCString(module, getPtr(module, base + 28)),
      });
    }
    return issues;
  }

  function createSessionApi(module, fns, statusMessage, sessionPtr) {
    let currentSession = asU32(sessionPtr);
    const finalizerDetachToken = {};

    function ensureOpen() {
      if (!currentSession) {
        const error = new Error("session is closed");
        error.status = 1;
        throw error;
      }
      return currentSession;
    }

    function closeInternal() {
      if (!currentSession) {
        return;
      }
      const ptrPtr = module._malloc(SIZE_POINTER);
      try {
        setPtr(module, ptrPtr, currentSession);
        const status = fns.closeSession(ptrPtr);
        throwIfStatus(statusMessage, status);
        currentSession = 0;
        sessionFinalizer?.unregister(finalizerDetachToken);
      } finally {
        module._free(ptrPtr);
      }
    }

    const sessionApi = {
      close() {
        closeInternal();
      },

      exportBytes() {
        const session = ensureOpen();
        const outBytesPtr = module._malloc(SIZE_POINTER);
        const outLenPtr = module._malloc(4);
        let bytesPtr = 0;
        try {
          setPtr(module, outBytesPtr, 0);
          setI32(module, outLenPtr, 0);
          const status = fns.exportBytes(session, outBytesPtr, outLenPtr);
          throwIfStatus(statusMessage, status);
          bytesPtr = getPtr(module, outBytesPtr);
          const length = asU32(getI32(module, outLenPtr));
          return bytesPtr && length > 0
            ? readBytes(module, bytesPtr, length)
            : new Uint8Array(0);
        } finally {
          // JS 复制失败时也释放 WASM 输出，避免大文件导出逐次泄漏。
          if (bytesPtr) {
            fns.freeBytes(bytesPtr);
          }
          module._free(outLenPtr);
          module._free(outBytesPtr);
        }
      },

      readBasicTags() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_BASIC_TAGS);
        try {
          const status = fns.readBasicTags(session, outPtr);
          throwIfStatus(statusMessage, status);
          return parseBasicTags(module, outPtr);
        } finally {
          fns.freeBasicTags(outPtr);
          module._free(outPtr);
        }
      },

      writeBasicTags(tags, id3v2Version) {
        const session = ensureOpen();
        const allocations = [];
        const tagPtr = module._malloc(SIZE_BASIC_TAGS);
        allocations.push(tagPtr);
        writeBasicTagsStruct(module, tagPtr, tags || {}, allocations);
        try {
          const status = fns.writeBasicTags(session, tagPtr, asU32(id3v2Version || 4));
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      readAudioProperties() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_AUDIO_PROPERTIES);
        try {
          const status = fns.readAudioProperties(session, outPtr);
          if (status === STATUS_NOT_FOUND) {
            return null;
          }
          throwIfStatus(statusMessage, status);
          return parseAudioProperties(module, outPtr);
        } finally {
          module._free(outPtr);
        }
      },

      probeCapabilities() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_SESSION_CAPABILITIES);
        try {
          const status = fns.probeCapabilities(session, outPtr);
          throwIfStatus(statusMessage, status);
          return parseSessionCapabilities(module, outPtr);
        } finally {
          module._free(outPtr);
        }
      },

      readPropertyMap() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_PROPERTY_MAP);
        try {
          const status = fns.readPropertyMap(session, outPtr);
          throwIfStatus(statusMessage, status);
          return parsePropertyMap(module, outPtr);
        } finally {
          fns.freePropertyMap(outPtr);
          module._free(outPtr);
        }
      },

      writePropertyMap(map) {
        const session = ensureOpen();
        const allocations = [];
        const mapPtr = allocPropertyMap(module, map, allocations);
        try {
          const status = fns.writePropertyMap(session, mapPtr);
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      readPictures() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_PICTURE_LIST);
        try {
          const status = fns.readPictures(session, outPtr);
          throwIfStatus(statusMessage, status);
          return parsePictures(module, outPtr);
        } finally {
          fns.freePictureList(outPtr);
          module._free(outPtr);
        }
      },

      writePictures(pictures, clearExisting) {
        const session = ensureOpen();
        const allocations = [];
        const listPtr = allocPictures(module, pictures, allocations);
        try {
          const status = fns.writePictures(session, listPtr, clearExisting ? 1 : 0);
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      readLyrics(opts) {
        const session = ensureOpen();
        const allocations = [];
        const langPtr = utf8Encode(module, opts && opts.language, allocations);
        const descPtr = utf8Encode(module, opts && opts.description, allocations);
        const outPtrPtr = module._malloc(SIZE_POINTER);
        allocations.push(outPtrPtr);
        setPtr(module, outPtrPtr, 0);
        try {
          const status = fns.readLyrics(session, langPtr, descPtr, outPtrPtr);
          if (status === STATUS_NOT_FOUND) {
            return null;
          }
          throwIfStatus(statusMessage, status);
          const textPtr = getPtr(module, outPtrPtr);
          if (!textPtr) {
            return "";
          }
          const text = readCString(module, textPtr) || "";
          fns.freeString(textPtr);
          setPtr(module, outPtrPtr, 0);
          return text;
        } finally {
          const leaked = getPtr(module, outPtrPtr);
          if (leaked) {
            fns.freeString(leaked);
          }
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      writeLyrics(text, opts) {
        const session = ensureOpen();
        const allocations = [];
        const textPtr = utf8Encode(module, text || "", allocations);
        const langPtr = utf8Encode(module, opts && opts.language, allocations);
        const descPtr = utf8Encode(module, opts && opts.description, allocations);
        try {
          const status = fns.writeLyrics(
            session,
            textPtr,
            langPtr,
            descPtr,
            asU32(opts && opts.id3v2Version ? opts.id3v2Version : 4),
          );
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      clearLyrics(opts) {
        const session = ensureOpen();
        const allocations = [];
        const langPtr = utf8Encode(module, opts && opts.language, allocations);
        const descPtr = utf8Encode(module, opts && opts.description, allocations);
        try {
          const status = fns.clearLyrics(
            session,
            langPtr,
            descPtr,
            asU32(opts && opts.id3v2Version ? opts.id3v2Version : 4),
          );
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      saveMp3WithId3v2Version(version) {
        const session = ensureOpen();
        const status = fns.saveWithVersion(session, asU32(version || 4));
        throwIfStatus(statusMessage, status);
      },

      readSyncedLyrics() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_SYLT_TRACK_LIST);
        try {
          const status = fns.readSylt(session, outPtr);
          if (status === STATUS_NOT_FOUND) {
            return [];
          }
          throwIfStatus(statusMessage, status);
          return parseSyltTracks(module, outPtr);
        } finally {
          fns.freeSyltTrackList(outPtr);
          module._free(outPtr);
        }
      },

      writeSyncedLyrics(tracks, opts) {
        const session = ensureOpen();
        const allocations = [];
        const rows = Array.isArray(tracks) ? tracks : [];
        const tracksPtr = allocSyltTracks(module, rows, allocations);
        try {
          const status = fns.writeSylt(
            session,
            tracksPtr,
            rows.length,
            asU32(opts && opts.mergeMode ? opts.mergeMode : 0),
            asU32(opts && opts.id3v2Version ? opts.id3v2Version : 4),
          );
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      clearSyncedLyrics(opts) {
        const session = ensureOpen();
        const allocations = [];
        let filterPtr = 0;
        if (opts && opts.filter) {
          filterPtr = module._malloc(SIZE_SYLT_FILTER);
          allocations.push(filterPtr);
          setPtr(module, filterPtr + 0, utf8Encode(module, opts.filter.language, allocations));
          setPtr(module, filterPtr + 4, utf8Encode(module, opts.filter.description, allocations));
          const filterType = opts.filter.type === undefined || opts.filter.type === null
            ? -1
            : (opts.filter.type | 0);
          setI32(module, filterPtr + 8, filterType);
        }

        try {
          const status = fns.clearSylt(
            session,
            filterPtr,
            asU32(opts && opts.id3v2Version ? opts.id3v2Version : 4),
          );
          throwIfStatus(statusMessage, status);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },

      scanTextIssues() {
        const session = ensureOpen();
        const outPtr = allocZeroed(module, SIZE_TEXT_ISSUE_LIST);
        try {
          const status = fns.scanTextIssues(session, outPtr);
          throwIfStatus(statusMessage, status);
          return parseTextIssues(module, outPtr);
        } finally {
          fns.freeTextIssueList(outPtr);
          module._free(outPtr);
        }
      },
    };
    sessionFinalizer?.register(
      sessionApi,
      { finalizeSession: fns.finalizeSession, session: currentSession },
      finalizerDetachToken,
    );
    return sessionApi;
  }

  function createTaglibBridge(module) {
    const fns = {
      apiVersion: module.cwrap("tlb_api_version", "number", []),
      abiFieldCount: module.cwrap("tlb_abi_field_count", "number", []),
      abiFields: module.cwrap("tlb_abi_fields", "number", []),
      statusMessage: module.cwrap("tlb_status_message", "string", ["number"]),
      openSessionFromBytes: module.cwrap("tlb_session_open_from_bytes", "number", ["number", "number", "number", "number"]),
      closeSession: module.cwrap("tlb_session_close", "number", ["number"]),
      finalizeSession: module.cwrap("tlb_session_finalize", null, ["number"]),
      exportBytes: module.cwrap("tlb_session_export_bytes", "number", ["number", "number", "number"]),

      readBasicTags: module.cwrap("tlb_session_read_basic_tags", "number", ["number", "number"]),
      writeBasicTags: module.cwrap("tlb_session_write_basic_tags", "number", ["number", "number", "number"]),
      readAudioProperties: module.cwrap("tlb_session_read_audio_properties", "number", ["number", "number"]),
      probeCapabilities: module.cwrap("tlb_session_probe_capabilities", "number", ["number", "number"]),

      readPropertyMap: module.cwrap("tlb_session_read_property_map", "number", ["number", "number"]),
      writePropertyMap: module.cwrap("tlb_session_write_property_map", "number", ["number", "number"]),

      readPictures: module.cwrap("tlb_session_read_pictures", "number", ["number", "number"]),
      writePictures: module.cwrap("tlb_session_write_pictures", "number", ["number", "number", "number"]),

      readLyrics: module.cwrap("tlb_session_read_lyrics", "number", ["number", "number", "number", "number"]),
      writeLyrics: module.cwrap("tlb_session_write_lyrics", "number", ["number", "number", "number", "number", "number"]),
      clearLyrics: module.cwrap("tlb_session_clear_lyrics", "number", ["number", "number", "number", "number"]),

      saveWithVersion: module.cwrap("tlb_session_mp3_save_with_id3v2_version", "number", ["number", "number"]),

      readSylt: module.cwrap("tlb_session_mp3_sylt_read", "number", ["number", "number"]),
      writeSylt: module.cwrap("tlb_session_mp3_sylt_write", "number", ["number", "number", "number", "number", "number"]),
      clearSylt: module.cwrap("tlb_session_mp3_sylt_clear", "number", ["number", "number", "number"]),

      scanTextIssues: module.cwrap("tlb_session_text_issues_scan", "number", ["number", "number"]),

      freeString: module.cwrap("tlb_free_string", null, ["number"]),
      freeBytes: module.cwrap("tlb_free_bytes", null, ["number"]),
      freeBasicTags: module.cwrap("tlb_free_basic_tags", null, ["number"]),
      freePropertyMap: module.cwrap("tlb_free_property_map", null, ["number"]),
      freePictureList: module.cwrap("tlb_free_picture_list", null, ["number"]),
      freeSyltTrackList: module.cwrap("tlb_free_sylt_track_list", null, ["number"]),
      freeTextIssueList: module.cwrap("tlb_free_text_issue_list", null, ["number"]),
    };


    verifyBridgeAbi(module, fns);

    return {
      openSessionFromBytes(bytes, nameHint) {
        const allocations = [];
        const inBytes = allocInputBytes(module, bytes, allocations);
        const namePtr = utf8Encode(module, nameHint, allocations);
        const outSessionPtr = module._malloc(SIZE_POINTER);
        allocations.push(outSessionPtr);
        setPtr(module, outSessionPtr, 0);

        try {
          const status = fns.openSessionFromBytes(
            inBytes.ptr,
            inBytes.length,
            namePtr,
            outSessionPtr,
          );
          throwIfStatus(fns.statusMessage, status);
          const sessionPtr = getPtr(module, outSessionPtr);
          return createSessionApi(module, fns, fns.statusMessage, sessionPtr);
        } finally {
          for (let i = allocations.length - 1; i >= 0; i -= 1) {
            module._free(allocations[i]);
          }
        }
      },
    };
  }

  async function initTaglibBridge(moduleFactory, moduleOptions) {
    const module = await moduleFactory(moduleOptions || {});
    const bridge = createTaglibBridge(module);
    globalScope.__taglibBridge = bridge;
    return bridge;
  }

  globalScope.createTaglibBridge = createTaglibBridge;
  globalScope.initTaglibBridge = initTaglibBridge;
})(typeof globalThis !== "undefined" ? globalThis : window);
