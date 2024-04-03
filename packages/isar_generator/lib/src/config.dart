import 'dart:io';

import 'package:yaml/yaml.dart';

const _pubspecFile = 'pubspec.yaml';
const _pubspecKey = 'isar';

/// Config reads and holds configuration for the code generator.
///
/// Expected format in pubspec.yaml:
/// ```
/// objectbox:
///   output_dir: custom
///   # Or optionally specify lib and test folder separately.
///   # output_dir:
///   #   lib: custom
///   #   test: other
/// ```
class Config {
  Config({
    this.classesToIgnore = const [],
    this.skipNotSupportedProperty = true,
  });

  factory Config.readFromPubspec() {
    final file = File(_pubspecFile);
    if (file.existsSync()) {
      final yaml = loadYaml(file.readAsStringSync())[_pubspecKey] as YamlMap?;
      if (yaml != null) {
        late final bool skipNotSupportedProperty;
        late final List<String> classesToIgnore;

        final outDirYaml = yaml['output_dir'];
        final ignoreClasses = yaml['ignore_super_classes'];
        final optionsYaml = yaml['options'];

        if (ignoreClasses is YamlList) {
          classesToIgnore = ignoreClasses.nodes.map((e) => e.value.toString()).toList();
        } else {
          classesToIgnore = [];
        }

        if (optionsYaml is YamlMap) {
          skipNotSupportedProperty = optionsYaml['skip_not_supported_property'] as bool? ?? true;
        } else {
          skipNotSupportedProperty = true;
        }

        return Config(
          classesToIgnore: classesToIgnore,
          skipNotSupportedProperty: skipNotSupportedProperty,
        );
      }
    }
    return Config();
  }
  final List<String> classesToIgnore;
  final bool skipNotSupportedProperty;
}
