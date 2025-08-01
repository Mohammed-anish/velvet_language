import 'package:velvet_cmp/parser/ast_classes.dart';

class klassObject {
  final List<VariableDeclarationNode> fields;
  final List<FunctionDecl> methods;
  final Map<String, dynamic> _statics = {};

  klassObject(
      {required this.fields,
      required this.methods,
      required Function(Node node) execute}) {
    fields
        .where(
      (element) => element.isStatic,
    )
        .forEach(
      (element) {
        execute(StaticField(
            target: this, name: element.name, value: element.value));
      },
    );
  }

  instanciate(String name, Function(Node node) execute) {
    Map<String, FunctionDecl> functions = {};
    for (var e in methods) {
      functions[e.name] = e;
    }

    Map<String, dynamic> fields = {};

    for (var f in this.fields) {
      fields[f.name] = execute(f.value);
    }

    return KlassInstance(this, name, functions, fields);
  }

  setStatic(String name, dynamic value) {
    _statics.addAll({name: value});
  }

  dynamic getStatic(String name) {
    return _statics[name];
  }

  VariableDeclarationNode? getField(String name) {
    return fields
        .where(
          (element) => element.name == name,
        )
        .firstOrNull;
  }
}

class KlassInstance {
  final String name;
  final klassObject instanceOf;
  final Map<String, FunctionDecl> functions;
  final Map<String, dynamic> fields;

  KlassInstance(this.instanceOf, this.name, this.functions, this.fields);
  setField(String name, dynamic value) {
    fields[name] = value;
  }

  getField(String name) {
    return fields[name];
  }

  bool has(String name) {
    return fields.containsKey(name);
  }

  @override
  String toString() => 'Instance of $name';
}

class StaticField extends Node {
  final klassObject target;
  final Node value;
  final String name;
  StaticField({required this.target, required this.name, required this.value});
}

/*
psudo code

parentScope['Person']= ClassObjet( fields={ name:VariableDeclaration(), age:VariableDeclaration() } , methods={ test : FunctionDecl() } );


instance create

scope['p']= ClassInstance(ClassObject) //it has fields evaled



find p in scope (any) 
(p as ClassInstance).call('test',args:[]) 



 */
