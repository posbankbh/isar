part of isar;

/// Annotate a property or accessor in an Isar collection to ignore it.
const ignore = Ignore();

/// Annotate a property or accessor in an Isar collection to ignore it.
@Target({TargetKind.field, TargetKind.getter})
class Ignore {
  /// Annotate a property or accessor in an Isar collection to ignore it.
  const Ignore();
}

/// Annotate a property or accessor in an Isar collection to include it.
const include = Include();

/// Annotate a property or accessor in an Isar collection to include it.
@Target({TargetKind.field, TargetKind.getter})
class Include {
  /// Annotate a property or accessor in an Isar collection to include it.
  const Include();
}
