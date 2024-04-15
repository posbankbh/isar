// ignore_for_file: public_member_api_docs
part of isar;

Map<TKey, TValue>? decodeMap<TKey, TValue>(String? data) {
  try {
    if (data == null) return null;
    return (jsonDecode(data) as Map?)?.cast<TKey, TValue>();
  } catch (_) {}
  return null;
}

dynamic decodeDynamic(String? data) {
  try {
    if (data == null || data.isEmpty) return null;
    return jsonDecode(data);
  } catch (_) {}
}
