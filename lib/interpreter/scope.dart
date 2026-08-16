import 'package:velvet_cmp/parser/ast_classes.dart';

mixin Scopes {
  List<Map<String, dynamic>> scopes = [{}];
  List<Map<String, List<List<Node>>>> reactiveScopes = [{}];

  void pushScope() {
    scopes.add({});
    reactiveScopes.add({});
  }

  void popScope() {
    scopes.removeLast();
    reactiveScopes.removeLast();
  }

  dynamic getVar(String name) {
    for (int i = scopes.length - 1; i >= 0; i--) {
      if (scopes[i].containsKey(name)) return scopes[i][name];
    }
    throw 'Variable not found: $name';
  }

  void setVar(String name, dynamic value) {
    for (int i = scopes.length - 1; i >= 0; i--) {
      if (scopes[i].containsKey(name)) {
        scopes[i][name] = value;
        return;
      }
    }
    scopes.last[name] = value;
  }

  void defineVar(String name, dynamic value) {
    scopes.last[name] = value;
  }

  bool checkReactive(String name) {
    for (int i = reactiveScopes.length - 1; i >= 0; i--) {
      if (reactiveScopes[i].containsKey(name)) return true;
    }
    return false;
  }

  setReactive(String name, List<Node> body) {
    if (reactiveScopes.last.containsKey(name)) {
      reactiveScopes.last[name]?.add(body);
    } else {
      reactiveScopes.last.addAll({
        name: [body]
      });
    }
  }

  notifyReactive(
      String name, String value, Function(List<Node> nodes) onNoify) {
    for (int i = reactiveScopes.length - 1; i >= 0; i--) {
      if (reactiveScopes[i].containsKey(name)) {
        var previousValue = getVar(name);
        //all listeners
        if (previousValue != value) {
          for (var x in reactiveScopes[i][name]!) {
            onNoify(x);
          }
        }
      }
    }
  }

  setEmptyReactive(String name) {
    reactiveScopes.last[name] = [];
  }

  setGlobal(String key, dynamic value) {
    scopes.first.addAll({key: value});
  }

  getGlobal(String key) {
    return scopes.first[key];
  }
}
