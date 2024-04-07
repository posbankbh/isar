// ignore_for_file: lines_longer_than_80_chars

part of isar;

/// Annotation to nest objects of this type in collections.
const embedded = Embedded();

/// Annotation to nest objects of this type in collections.
@Target({TargetKind.classType})
class Embedded {
  /// Annotation to nest objects of this type in collections.
  const Embedded({this.inheritance = true, this.ignore = const {}, this.converters = const {}});

  /// Should properties and accessors of parent classes and mixins be included?
  final bool inheritance;

  /// A list of properties or getter names that Isar should ignore.
  final Set<String> ignore;

  /// A list of type converters
  final Set<Converter> converters;
}
