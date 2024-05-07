// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars
part of isar;

Map<TKey, TValue>? decodeMap<TKey, TValue>(
  String? data, {
  MapEntry<TKey, TValue> Function(dynamic, dynamic)? converter,
}) {
  try {
    if (data == null) return null;

    final map = jsonDecode(data) as Map?;

    if (map == null) return null;

    if (converter != null) {
      return map.map((key, value) => converter(key, value));
    }

    return map.cast<TKey, TValue>();
  } catch (_) {}
  return null;
}

dynamic decodeDynamic(String? data) {
  try {
    if (data == null || data.isEmpty) return null;
    return jsonDecode(data);
  } catch (_) {}
}

Map<dynamic, dynamic> convertMapEnumToString(Map<dynamic, dynamic> originalMap) {
  return originalMap.map((key, value) {
    return MapEntry(key is Enum ? key.name : key, value is Enum ? value.name : value);
  });
}

String nullToEmptyString(String? id) => id ?? '';
