import 'dart:io';
import 'dart:convert';
import 'package:velvet_cmp/runtime/class_object.dart';
import 'package:velvet_cmp/runtime/runtime.dart';

class KlassBuilder {
  final String className;
  KlassBuilder(this.className);

  void define(String name, dynamic Function(List args) fn) {
    Runtime.outerMethods['$className.$name'] = fn;
  }

  void defineStatic(String name, dynamic Function(List args) fn) {
    Runtime.outerStaticMethods['$className.$name'] = fn;
  }

  void field(String name, dynamic value) {
    Runtime.outerFields.putIfAbsent(className, () => {})[name] = value;
  }

  void getter(String name, dynamic Function(List args) fn) {
    Runtime.outerGetters['$className.$name'] = fn;
  }

  void setter(String name, dynamic Function(List args) fn) {
    Runtime.outerSetters['$className.$name'] = fn;
  }

  void staticField(String name, dynamic value) {
    Runtime.setStatic(className, name, value);
  }
}

class Runtime {
  static Map outerMethods = {};
  static Map outerStaticMethods = {};
  static Map<String, dynamic> outerStaticFields = {};
  static Map<String, Map<String, dynamic>> outerFields = {};
  static Map outerGetters = {};
  static Map outerSetters = {};

  static Map<Type, String> primitiveClassBindings = {
    String: 'String',
    int: 'Number',
    double: 'Number',
    DateTime: 'DateTime',
  };

  static List<MapEntry<bool Function(dynamic), String>> primitiveTypeChecks = [];

  static void bindPrimitive(Type dartType, String velvetClassName) {
    primitiveClassBindings[dartType] = velvetClassName;
  }

  static void bindPrimitiveTypeCheck(bool Function(dynamic) check, String velvetClassName) {
    primitiveTypeChecks.add(MapEntry(check, velvetClassName));
  }

  static void register(String name, void Function(KlassBuilder klass) builder) {
    builder(KlassBuilder(name));
  }

  // Kept for backward compatibility if needed internally
  static void resgister(String name, dynamic Function(List args) fn) {
    outerMethods[name] = fn;
  }

  static dynamic get(String className, String fieldName) {
    return outerFields[className]?[fieldName];
  }

  static void set(String className, String fieldName, dynamic value) {
    outerFields.putIfAbsent(className, () => {})[fieldName] = value;
  }

  static dynamic getStatic(String className, String fieldName) {
    return outerStaticFields['$className.$fieldName'];
  }

  static void setStatic(String className, String fieldName, dynamic value) {
    outerStaticFields['$className.$fieldName'] = value;
  }

  static dynamic call(
      String identifier, List<dynamic> args, String? returnType) {
    if (outerMethods.containsKey(identifier)) {
      return outerMethods[identifier](args);
    } else if (outerStaticMethods.containsKey(identifier)) {
      return outerStaticMethods[identifier](args);
    } else {
      throw Exception('Outer method $identifier is not defined.');
    }
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
