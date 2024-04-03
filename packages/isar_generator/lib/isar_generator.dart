import 'package:build/build.dart';
import 'package:isar_generator/src/collection_generator.dart';
import 'package:isar_generator/src/config.dart';
import 'package:source_gen/source_gen.dart';

final _config = Config.readFromPubspec();


Builder getIsarGenerator(BuilderOptions options) => SharedPartBuilder(
      [
        IsarCollectionGenerator(_config),
        IsarEmbeddedGenerator(_config),
      ],
      'isar_generator',
    );
