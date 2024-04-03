import 'package:build/build.dart';
import 'package:isar_generator/src/collection_generator.dart';
import 'package:isar_generator/src/config.dart';
import 'package:source_gen/source_gen.dart';

final config = Config.readFromPubspec();

Builder getIsarGenerator(BuilderOptions options) => SharedPartBuilder(
      [
        IsarCollectionGenerator(),
        IsarEmbeddedGenerator(),
      ],
      'isar_generator',
    );
