import 'package:velvet_cmp/runtime/class_object.dart';

class RunTimeType {
  static String check(dynamic value) {
    if (value is KlassInstance) {
      return value.name;
    }

    var dartType = value.runtimeType.toString();

    const typeMap = {
      'String': 'String',
      'int': 'Number',
      'double': 'Number',
      'bool': 'bool',
      'Null': 'null',
    };

    if (typeMap.containsKey(dartType)) {
      return typeMap[dartType]!;
    }

    // Otherwise, assume it's a custom class
    return dartType; // or 'object' if your language doesn't use class names directly
  }
}
