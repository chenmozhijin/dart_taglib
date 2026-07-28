// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// Cross-platform TagLib metadata reading and writing for Dart applications.
library;

export 'src/api/dirty_text_repair.dart'
    show
        CharsetDetection,
        CharsetDetector,
        CharsetNormalizerDetector,
        DirtyTextRepairEngine;
export 'src/api/taglib_api.dart';
export 'src/api/taglib_exception.dart';
export 'src/api/taglib_session.dart';
export 'src/backend/taglib_backend.dart'
    show
        SyltMergeMode,
        TaglibBackend,
        TaglibFileDescriptorBackend,
        TaglibPathBackend,
        TaglibSessionBackend,
        TaglibSessionCapabilityProbeBackend;
export 'src/models/audio_properties.dart';
export 'src/models/basic_tags.dart';
export 'src/models/id3v2_version.dart';
export 'src/models/picture_item.dart';
export 'src/models/property_map.dart';
export 'src/models/read_tags_result.dart';
export 'src/models/session_capabilities.dart';
export 'src/models/synced_lyrics.dart';
export 'src/models/text_issue.dart';
export 'src/wasm_web/wasm_backend_exports.dart'
    show
        WasmTaglibBackend,
        hasTaglibWasmBridge,
        initializeTaglibWasmBridge,
        taglibWasmDefaultAssetBaseUrl;
