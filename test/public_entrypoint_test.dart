// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:dart_taglib/dart_taglib.dart';
import 'package:test/test.dart';

void main() {
  test('public entrypoint exposes the core API surface', () {
    final createApi = TaglibApi.new;
    const tags = BasicTags(title: 'hello');

    expect(createApi, isA<TaglibApi Function()>());
    expect(tags.title, 'hello');
    expect(Id3v2Version.v24, isNotNull);
    expect(SyltMergeMode.replaceByKey, isNotNull);
    expect(const PictureFileItem(path: 'cover.jpg').path, 'cover.jpg');
  });

  test('BasicTags.copyWith can keep or clear nullable fields', () {
    const tags = BasicTags(title: 'title', artist: 'artist');

    expect(tags.copyWith().title, 'title');
    expect(tags.copyWith(title: null).title, isNull);
    expect(tags.copyWith(title: 'next').title, 'next');
  });

  test('public models defensively copy mutable collections and bytes', () {
    final values = <String>['a'];
    final item = PropertyItem(key: 'TITLE', values: values);
    values.add('b');
    expect(item.values, orderedEquals(<String>['a']));
    expect(() => item.values.add('c'), throwsUnsupportedError);

    final items = <PropertyItem>[item];
    final map = PropertyMap(items: items);
    items.clear();
    expect(map.items, hasLength(1));
    expect(() => map.items.clear(), throwsUnsupportedError);

    final entries = <SyncedLyricsEntry>[
      const SyncedLyricsEntry(time: 1, text: 'line'),
    ];
    final track = SyncedLyricsTrack(language: 'eng', entries: entries);
    entries.clear();
    expect(track.entries, hasLength(1));
    expect(() => track.entries.clear(), throwsUnsupportedError);

    final pictureBytes = Uint8List.fromList(<int>[1, 2, 3]);
    final picture = PictureItem(data: pictureBytes);
    pictureBytes[0] = 9;
    expect(picture.data, orderedEquals(<int>[1, 2, 3]));
    expect(() => picture.data[0] = 7, throwsUnsupportedError);
    expect(picture.data, orderedEquals(<int>[1, 2, 3]));

    final issueBytes = Uint8List.fromList(<int>[4, 5]);
    final issue = TextIssue(
      source: TextIssueSource.id3v1,
      fieldPath: 'id3v1.title',
      frameId: null,
      language: null,
      description: null,
      rawBytes: issueBytes,
      baselineDecoded: 'old',
    );
    issueBytes[0] = 8;
    expect(issue.rawBytes, orderedEquals(<int>[4, 5]));
    expect(() => issue.rawBytes[0] = 1, throwsUnsupportedError);
    expect(issue.rawBytes, orderedEquals(<int>[4, 5]));

    final fields = <String, RepairedTextValue>{
      'title': const RepairedTextValue(
        value: 'title',
        confidence: 1,
        repaired: false,
        uncertain: false,
      ),
    };
    final issues = <TextIssue>[issue];
    final result = ReadTagsResult(
      tags: const BasicTags(title: 'title'),
      fields: fields,
      issues: issues,
    );
    fields.clear();
    issues.clear();
    expect(result.fields, contains('title'));
    expect(result.issues, hasLength(1));
    expect(() => result.fields.clear(), throwsUnsupportedError);
    expect(() => result.issues.clear(), throwsUnsupportedError);
  });
}
