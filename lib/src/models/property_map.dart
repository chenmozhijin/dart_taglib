// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: MIT

/// One key and its ordered values in a generic TagLib property map.
class PropertyItem {
  /// Creates an item and stores an unmodifiable copy of [values].
  PropertyItem({required this.key, required List<String> values})
    : values = List<String>.unmodifiable(values);

  /// Property key.
  final String key;

  /// Unmodifiable ordered property values.
  final List<String> values;
}

/// Generic metadata properties not limited to `BasicTags`.
class PropertyMap {
  /// Creates a map and stores an unmodifiable copy of [items].
  PropertyMap({required List<PropertyItem> items})
    : items = List<PropertyItem>.unmodifiable(items);

  /// Unmodifiable ordered property items.
  final List<PropertyItem> items;

  /// Creates an empty property map.
  factory PropertyMap.empty() => PropertyMap(items: const <PropertyItem>[]);
}
