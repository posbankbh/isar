part of isar;

/// Annotate a property or accessor in an Isar collection to ignore it.
@Target({TargetKind.field, TargetKind.getter, TargetKind.classType})
class IsarConverter {
  /// Annotate a property or accessor in an Isar collection to ignore it.
  const IsarConverter(this.converters);

  /// A list of converters
  final List<Type> converters;
}
