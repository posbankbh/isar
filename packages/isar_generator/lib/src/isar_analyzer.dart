// ignore_for_file: lines_longer_than_80_chars

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dartx/dartx.dart';
import 'package:isar/isar.dart';

import 'package:isar_generator/src/helper.dart';
import 'package:isar_generator/src/isar_type.dart';
import 'package:isar_generator/src/object_info.dart';
import 'package:source_gen/source_gen.dart';

class IsarAnalyzer {
  ObjectInfo analyzeCollection(Element element) {
    final constructor = _checkValidClass(element);
    final modelClass = element as ClassElement;

    final properties = <ObjectProperty>[];
    final links = <ObjectLink>[];
    for (final propertyElement in modelClass.allAccessors) {
      if (propertyElement.isLink || propertyElement.isLinks) {
        final link = analyzeObjectLink(propertyElement);
        links.add(link);
      } else {
        final property = analyzeObjectProperty(propertyElement, constructor, modelClass);
        properties.add(property);
      }
    }
    _checkValidPropertiesConstructor(properties, constructor);
    if (links.map((e) => e.isarName).distinct().length != links.length) {
      err('Two or more links have the same name.', modelClass);
    }

    final indexes = <ObjectIndex>[];
    for (final propertyElement in modelClass.allAccessors) {
      indexes.addAll(analyzeObjectIndex(properties, propertyElement));
    }
    if (indexes.map((e) => e.name).distinct().length != indexes.length) {
      err('Two or more indexes have the same name.', modelClass);
    }

    final idProperties = properties.where((it) => it.isId);
    if (idProperties.isEmpty) {
      err(
        'No id property defined. Use the "Id" type for your id property.',
        modelClass,
      );
    } else if (idProperties.length > 1) {
      err('Two or more properties with type "Id" defined.', modelClass);
    }

    return ObjectInfo(
      dartName: modelClass.displayName,
      isarName: modelClass.isarName,
      accessor: modelClass.collectionAccessor,
      properties: properties,
      embeddedDartNames: _getEmbeddedDartNames(element),
      indexes: indexes,
      links: links,
    );
  }

  ObjectInfo analyzeEmbedded(Element element) {
    final constructor = _checkValidClass(element);
    final modelClass = element as ClassElement;

    final properties = <ObjectProperty>[];
    for (final propertyElement in modelClass.allAccessors) {
      if (propertyElement.isLink || propertyElement.isLinks) {
        err('Embedded objects must not contain links', propertyElement);
      } else {
        final property = analyzeObjectProperty(propertyElement, constructor, modelClass);
        properties.add(property);
      }
    }
    _checkValidPropertiesConstructor(properties, constructor);

    // final hasIndex = modelClass.allAccessors.any(
    //   (it) => it.indexAnnotations.isNotEmpty,
    // );
    // if (hasIndex) {
    //   err('Embedded objects must not have indexes.', modelClass);
    // }

    final hasIdProperty = properties.any((it) => it.isId);
    if (hasIdProperty) {
      //err('Embedded objects must not define an id.', modelClass);
      properties.remove(properties.firstWhere((it) => it.isId));
    }

    return ObjectInfo(
      dartName: modelClass.displayName,
      isarName: modelClass.isarName,
      properties: properties,
    );
  }

  ConstructorElement _checkValidClass(Element modelClass) {
    if (modelClass is! ClassElement || modelClass is EnumElement || modelClass is MixinElement) {
      err(
        'Only classes may be annotated with @Collection or @Embedded.',
        modelClass,
      );
    }

    if (modelClass.isAbstract) {
      err('Class must not be abstract.', modelClass);
    }

    if (!modelClass.isPublic) {
      err('Class must be public.', modelClass);
    }

    final constructor = modelClass.constructors.firstOrNullWhere((ConstructorElement c) => c.periodOffset == null);
    if (constructor == null) {
      err('Class needs an unnamed constructor.', modelClass);
    }

    final hasCollectionSupertype = modelClass.allSupertypes.any((type) {
      return type.element.collectionAnnotation != null || type.element.embeddedAnnotation != null;
    });
    if (hasCollectionSupertype) {
      err(
        'Class must not have a supertype annotated with @Collection or '
        '@Embedded.',
        modelClass,
      );
    }

    return constructor;
  }

  void _checkValidPropertiesConstructor(
    List<ObjectProperty> properties,
    ConstructorElement constructor,
  ) {
    if (properties.map((e) => e.isarName).distinct().length != properties.length) {
      err(
        'Two or more properties have the same name.',
        constructor.enclosingElement,
      );
    }

    final unknownConstructorParameter = constructor.parameters.firstOrNullWhere(
      (p) => p.isRequired && properties.none((e) => e.dartName == p.name),
    );
    if (unknownConstructorParameter != null) {
      err(
        'Constructor parameter does not match a property.',
        unknownConstructorParameter,
      );
    }
  }

  Map<String, String> _getEmbeddedDartNames(ClassElement element) {
    void _fillNames(Map<String, String> names, ClassElement element) {
      for (final property in element.allAccessors) {
        final type = property.type.scalarType.element;
        if (type is ClassElement && type.embeddedAnnotation != null) {
          final isarName = type.isarName;
          if (!names.containsKey(isarName)) {
            names[type.isarName] = type.displayName;
            _fillNames(names, type);
          }
        }
      }
    }

    final names = <String, String>{};
    _fillNames(names, element);
    return names;
  }

  ObjectProperty analyzeObjectProperty(
    PropertyInducingElement property,
    ConstructorElement constructor,
    ClassElement modelClass,
  ) {
    final dartType = property.type;
    final scalarDartType = dartType.scalarType;
    Map<String, dynamic>? enumMap;
    String? enumPropertyName;
    String? defaultEnumElement;
    ConverterMetaData? converter;

    late final IsarType isarType;
    if (scalarDartType.element is EnumElement) {
      final enumeratedAnn = property.enumeratedAnnotation;
      if (enumeratedAnn == null) {
        err('Enum property must be annotated with @enumerated.', property);
      }

      final enumClass = scalarDartType.element! as EnumElement;
      final enumElements = enumClass.fields.where((f) => f.isEnumConstant).toList();
      defaultEnumElement = '${enumClass.name}.${enumElements.first.name}';

      if (enumeratedAnn.type == EnumType.ordinal) {
        isarType = dartType.isDartCoreList ? IsarType.byteList : IsarType.byte;
        enumMap = {
          for (var i = 0; i < enumElements.length; i++) enumElements[i].name: i,
        };
        enumPropertyName = 'index';
      } else if (enumeratedAnn.type == EnumType.ordinal32) {
        isarType = dartType.isDartCoreList ? IsarType.intList : IsarType.int;

        enumMap = {
          for (var i = 0; i < enumElements.length; i++) enumElements[i].name: i,
        };
        enumPropertyName = 'index';
      } else if (enumeratedAnn.type == EnumType.name) {
        isarType = dartType.isDartCoreList ? IsarType.stringList : IsarType.string;
        enumMap = {
          for (final value in enumElements) value.name: value.name,
        };
        enumPropertyName = 'name';
      } else {
        enumPropertyName = enumeratedAnn.property;
        if (enumPropertyName == null) {
          err(
            'Enums with type EnumType.value must specify which property '
            'should be used.',
            property,
          );
        }
        final enumProperty = enumClass.getField(enumPropertyName);
        if (enumProperty == null || enumProperty.isEnumConstant) {
          err('Enum property "$enumProperty" does not exist.', property);
        } else if (enumProperty.nonSynthetic is PropertyAccessorElement) {
          err('Only fields are supported for enum properties', enumProperty);
        }

        final enumIsarType = enumProperty.type.isarType;
        if (enumIsarType != IsarType.byte &&
            enumIsarType != IsarType.int &&
            enumIsarType != IsarType.long &&
            enumIsarType != IsarType.string) {
          err('Unsupported enum property type.', enumProperty);
        }

        isarType = dartType.isDartCoreList ? enumIsarType!.listType : enumIsarType!;
        enumMap = {};
        for (final element in enumElements) {
          final property = element.computeConstantValue()!.getField(enumPropertyName)!;
          final propertyValue = property.toBoolValue() ?? property.toIntValue() ?? property.toDoubleValue() ?? property.toStringValue();
          if (propertyValue == null) {
            err(
              'Null values are not supported for enum properties.',
              enumProperty,
            );
          }

          if (enumMap.values.contains(propertyValue)) {
            err(
              'Enum property has duplicate values.',
              enumProperty,
            );
          }
          enumMap[element.name] = propertyValue;
        }
      }
    } else {
      if (dartType.isarType != null) {
        isarType = dartType.isarType!;
      } else {
        //check if we have converter for this field type
        converter = _checkConverters(dartType, modelClass);
        if (converter != null) {
          if (converter.converterType == 'IntTypeConverter') {
            isarType = dartType.isDartCoreList ? IsarType.intList : IsarType.int;
          } else if (converter.converterType == 'StringTypeConverter') {
            isarType = dartType.isDartCoreList ? IsarType.stringList : IsarType.string;
          } else if (converter.converterType == 'DoubleTypeConverter') {
            isarType = dartType.isDartCoreList ? IsarType.doubleList : IsarType.double;
          } else if (converter.converterType == 'BoolTypeConverter') {
            isarType = dartType.isDartCoreList ? IsarType.boolList : IsarType.bool;
          } else {
            throw InvalidGenerationSourceError('Non implemented');
          }
        } else {
          err(
            'Unsupported type. Please annotate the property with @ignore, Or use [Converters] - Ask Mohammed -.',
            property,
          );
        }
      }
    }

    final nullable = dartType.nullabilitySuffix != NullabilitySuffix.none;
    final elementNullable = isarType.isList && dartType.scalarType.nullabilitySuffix != NullabilitySuffix.none;

    if ((isarType == IsarType.byte && nullable) || (isarType == IsarType.byteList && elementNullable)) {
      err('Bytes must not be nullable.', property);
    }

    final constructorParameter = constructor.parameters.firstOrNullWhere((p) => p.name == property.name);
    int? constructorPosition;
    late PropertyDeser deserialize;
    if (constructorParameter != null) {
      //TODO:Disabled by POSBANK
      // if (constructorParameter.type != property.type) {
      //   err(
      //     'Constructor parameter type does not match property type',
      //     constructorParameter,
      //   );
      // }
      deserialize = constructorParameter.isNamed ? PropertyDeser.namedParam : PropertyDeser.positionalParam;
      constructorPosition = constructor.parameters.indexOf(constructorParameter);
    } else {
      deserialize = property.setter == null ? PropertyDeser.none : PropertyDeser.assign;
    }

    String? mapKeyType;
    String? mapValueType;
    if (dartType.isDartCoreMap) {
      final mapElement = dartType as ParameterizedType;
      mapKeyType = mapElement.typeArguments[0].getDisplayString(withNullability: true);
      mapValueType = mapElement.typeArguments[1].getDisplayString(withNullability: true);
    }

    return ObjectProperty(
      dartName: property.displayName,
      isarName: property.isarName,
      typeClassName: dartType.scalarType.element!.name!,
      targetIsarName: isarType.containsObject ? dartType.scalarType.element!.isarName : null,
      isarType: isarType,
      isId: dartType.isIsarId,
      enumMap: enumMap,
      enumProperty: enumPropertyName,
      defaultEnumElement: defaultEnumElement,
      nullable: nullable,
      elementNullable: elementNullable,
      userDefaultValue: constructorParameter?.defaultValueCode,
      deserialize: deserialize,
      assignable: property.setter != null,
      constructorPosition: constructorPosition,
      isMap: dartType.isDartCoreMap,
      mapKeyType: mapKeyType,
      mapValueType: mapValueType,
      isDynamic: dartType is DynamicType,
      converter: converter,
    );
  }

  ObjectLink analyzeObjectLink(PropertyInducingElement property) {
    if (property.type.nullabilitySuffix != NullabilitySuffix.none) {
      err('Link properties must not be nullable.', property);
    } else if (property.isLate) {
      err('Link properties must not be late.', property);
    }

    final type = property.type as ParameterizedType;
    final linkType = type.typeArguments[0];
    if (linkType.nullabilitySuffix != NullabilitySuffix.none) {
      err('Links type must not be nullable.', property);
    }

    final targetCol = linkType.element! as ClassElement;
    if (targetCol.collectionAnnotation == null) {
      err('Link target is not annotated with @collection');
    }

    final backlinkAnn = property.backlinkAnnotation;
    String? targetLinkIsarName;
    if (backlinkAnn != null) {
      final targetProperty = targetCol.allAccessors.firstOrNullWhere((e) => e.displayName == backlinkAnn.to);
      if (targetProperty == null) {
        err('Target of Backlink does not exist', property);
      } else if (targetProperty.backlinkAnnotation != null) {
        err('Target of Backlink is also a backlink', property);
      }

      if (!targetProperty.isLink && !targetProperty.isLinks) {
        err('Target of backlink is not a link', property);
      }

      final targetLink = analyzeObjectLink(targetProperty);
      targetLinkIsarName = targetLink.isarName;
    }

    return ObjectLink(
      dartName: property.displayName,
      isarName: property.isarName,
      targetLinkIsarName: targetLinkIsarName,
      targetCollectionDartName: linkType.element!.name!,
      targetCollectionIsarName: targetCol.isarName,
      isSingle: property.isLink,
    );
  }

  Iterable<ObjectIndex> analyzeObjectIndex(
    List<ObjectProperty> properties,
    PropertyInducingElement element,
  ) sync* {
    final property = properties.firstOrNullWhere((it) => it.dartName == element.name);
    if (property == null || property.isId) {
      return;
    }

    for (final index in element.indexAnnotations) {
      final indexProperties = <ObjectIndexProperty>[];
      final isString = property.isarType == IsarType.string || property.isarType == IsarType.stringList;
      final defaultType = property.isarType.isList || isString ? IndexType.hash : IndexType.value;

      indexProperties.add(
        ObjectIndexProperty(
          property: property,
          type: index.type ?? defaultType,
          caseSensitive: index.caseSensitive ?? isString,
        ),
      );
      for (final c in index.composite) {
        final compositeProperty = properties.firstOrNullWhere((it) => it.dartName == c.property);
        if (compositeProperty == null) {
          err('Property does not exist: "${c.property}".', element);
        } else if (compositeProperty.isId) {
          err('Ids cannot be indexed', element);
        } else {
          final isString = compositeProperty.isarType == IsarType.string || compositeProperty.isarType == IsarType.stringList;
          final defaultType = compositeProperty.isarType.isList || isString ? IndexType.hash : IndexType.value;
          indexProperties.add(
            ObjectIndexProperty(
              property: compositeProperty,
              type: c.type ?? defaultType,
              caseSensitive: c.caseSensitive ?? isString,
            ),
          );
        }
      }

      final name = index.name ?? indexProperties.map((e) => e.property.isarName).join('_');
      checkIsarName(name, element);

      final objectIndex = ObjectIndex(
        name: name,
        properties: indexProperties,
        unique: index.unique,
        replace: index.replace,
      );
      _verifyObjectIndex(objectIndex, element);

      yield objectIndex;
    }
  }

  void _verifyObjectIndex(ObjectIndex index, Element element) {
    final properties = index.properties;

    if (properties.map((it) => it.property.isarName).distinct().length != properties.length) {
      err('Composite index contains duplicate properties.', element);
    }

    for (var i = 0; i < properties.length; i++) {
      final property = properties[i];
      if (property.isarType.isList && property.type != IndexType.hash && properties.length > 1) {
        err('Composite indexes do not support non-hashed lists.', element);
      }
      if (property.isarType.containsFloat && i != properties.lastIndex) {
        err(
          'Only the last property of a composite index may be a '
          'double value.',
          element,
        );
      }
      if (property.isarType == IsarType.string) {
        if (property.type != IndexType.hash && i != properties.lastIndex) {
          err(
            'Only the last property of a composite index may be a '
            'non-hashed String.',
            element,
          );
        }
      }
      if (property.isarType.containsObject) {
        err(
          'Embedded objects may not be indexed.',
          element,
        );
      }
      if (property.type != IndexType.value) {
        if (!property.isarType.isList && property.isarType != IsarType.string) {
          err('Only Strings and Lists may be hashed.', element);
        } else if (property.isarType.containsFloat) {
          err('List<double> may must not be hashed.', element);
        }
      }
      if (property.isarType != IsarType.stringList && property.type == IndexType.hashElements) {
        err('Only String lists may have hashed elements.', element);
      }
    }

    if (!index.unique && index.replace) {
      err('Only unique indexes can replace.', element);
    }
  }

  ConverterMetaData? _checkConverters(DartType fieldDartType, ClassElement classElement) {
    final converters = classElement.isarConverters;

    if (converters != null) {
      for (final converter in converters) {
        final classElement = converter.element! as ClassElement;
        final type = classElement.interfaces[0].typeArguments[0];
        if (type.element == fieldDartType.element || fieldDartType.scalarType.element == fieldDartType.element) {
          return ConverterMetaData(classElement.name, classElement.interfaces[0].element.name);
        }
      }
    }

    return null;
  }
}
