class Runtime {
  static Map outerMethods = {};

  static resgister(String name, dynamic Function(List args) fn) {
    outerMethods[name] = fn;
  }

  static dynamic call(
      String identifier, List<String> args, String? returnType) {
    return outerMethods[identifier](args);
  }
}

///
///
/// Runtime.find('Person.exec',(e){
///
/// v
/// })
///
///
///
///
///
