class RunTimeType {
  static String check(dynamic value) {
    var dartType = value.runtimeType.toString();

    const typeMap = {
      'String': 'str',
      'int': 'num',
      'double': 'float',
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
