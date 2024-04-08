part of isar;

// ignore_for_file: public_member_api_docs, eol_at_end_of_file

//Base class (used as marker interface)
abstract class Converter {
  Object? write(Object? obj);
  Object? read(Object? dbValue);
}

abstract class IntTypeConverter<T extends Object> implements Converter {
  @override
  int? write(covariant T? obj);
  @override
  T? read(covariant int? dbValue);
}

abstract class StringTypeConverter<T extends Object> implements Converter {
  @override
  String? write(covariant T? obj);
  @override
  T? read(covariant String? dbValue);
}

abstract class DoubleTypeConverter<T extends Object> implements Converter {
  @override
  double? write(covariant T? obj);
  @override
  T? read(covariant double? dbValue);
}

abstract class BoolTypeConverter<T extends Object> implements Converter {
  @override
  bool? write(covariant T? obj);
  @override
  T? read(covariant bool? dbValue);
}
