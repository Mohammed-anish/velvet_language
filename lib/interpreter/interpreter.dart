import 'dart:io';
import 'dart:async';
import 'package:velvet_cmp/interpreter/scope.dart';
import 'package:velvet_cmp/interpreter/sys_functions.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/runtime/class_object.dart';
import 'package:velvet_cmp/runtime/external_registery.dart';
import 'package:velvet_cmp/runtime/runtime.dart';
import 'package:velvet_cmp/runtime/runtime_type.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';

class Interpreter with Scopes {
  Map<String, Node> functions = {};
  KlassInstance? currentThis;
  Interpreter() {
    OuterFunctionRegistry.register();
  }
  dynamic execute(Node ast, {List<Map<String, dynamic>>? customScope}) {
    if (customScope != null) {
      scopes = customScope;
    }
    if (ast is Programe) {
      if (getGlobal('__object_loaded') == null) {
        scopes.first['__object_loaded'] = true;
        execute(ImportNode(path: 'object.velv'));
      }
      for (final Node node in ast.body) {
        execute(node);
      }
    }

    if (ast is BineryNode) {
      if (ast.op == '&&') {
        final left = execute(ast.left);
        if (left == false) return false;
        return execute(ast.right);
      }
      if (ast.op == '||') {
        final left = execute(ast.left);
        if (left == true) return true;
        return execute(ast.right);
      }

      final left = execute(ast.left);
      final right = execute(ast.right);
      // print(
      //     'Binary ${ast.op} : left=$left (${left.runtimeType}), right=$right (${right.runtimeType})');

      if (ast.op == '+') {
        if (left is String || right is String) {
          return left.toString() + right.toString();
        }
        return left + right;
      }

      switch (ast.op) {
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          return left / right;
        case '==':
          return left == right;
        case '!=':
          return left != right;
        case '>':
          return left > right;
        case '<':
          return left < right;
        case '>=':
          return left >= right;
        case '<=':
          return left <= right;
        default:
          throw Exception('Unknown binary operator: ${ast.op}');
      }
    }
    if (ast is UnaryExpr) {
      var right = execute(ast.right);
      if (ast.operator == '-') return -right;
      if (ast.operator == '!') return !right;
      throw Exception('Unknown unary operator: ${ast.operator}');
    }
    if (ast is ExpressionStatement) {
      execute(ast.value);
    }

    if (ast is VariableDeclarationNode) {
      if (ast.kind != 'auto' &&
          ast.kind != RunTimeType.check(execute(ast.value))) {
        throw 'Variable needs ${ast.kind} but got ${RunTimeType.check(execute(ast.value))}';
      }
      defineVar(ast.name, execute(ast.value));

      if (ast.isReactive) {
        setEmptyReactive(ast.name);
      }
    }
    if (ast case StaticField static) {
      static.target.setStatic(static.name, execute(static.value));
    }

    if (ast is AssignmentNode) {
      if (ast.target case IdentifierNode idf) {
        if (checkReactive(idf.name)) {
          notifyReactive(
            idf.name,
            execute(ast.value),
            (nodes) {
              for (final Node node in nodes) {
                pushScope();
                execute(node);
                popScope();
              }
            },
          );
        }
        setVar(idf.name, execute(ast.value));
      }
      if (ast.target case MemberAccess member) {
        if (execute(member.object) case klassObject klass) {
          if (member.object is IdentifierNode) {
            var className = (member.object as IdentifierNode).name;
            var staticFieldKey = '$className.${member.property}';
            if (Runtime.outerStaticFields.containsKey(staticFieldKey)) {
              Runtime.outerStaticFields[staticFieldKey] = execute(ast.value);
              return;
            }
          }
          klass.setStatic(member.property, execute(ast.value));

          return;
        } else {
          KlassInstance? object = execute(member.object) as KlassInstance?;
          final value = execute(ast.value);

          var setterKey = '${object!.name}.${member.property}';
          if (Runtime.outerSetters.containsKey(setterKey)) {
            Runtime.outerSetters[setterKey]!([object, value]);
            return;
          }

          if (object.has(member.property)) {
            var kind = object.instanceOf.getField(member.property)?.kind;
            if (kind != 'auto' && (RunTimeType.check(value)) != kind) {
              throw Exception(
                  'Expected value type ${kind} but got ${(RunTimeType.check(value))}');
            }

            object.setField(member.property, value);
          } else {
            throw Exception('Invalid property!! ${member.property}');
          }
        }
      }
      if (ast.target case IndexAccessNode indexNode) {
        var targetObj = execute(indexNode.target);
        var indexVal = execute(indexNode.index);
        var value = execute(ast.value);
        if (targetObj is KlassInstance) {
          if (targetObj.functions.containsKey('set')) {
            Runtime.call(
                '${targetObj.name}.set', [targetObj, indexVal, value], null);
            return;
          } else if (targetObj.functions.containsKey('put')) {
            Runtime.call(
                '${targetObj.name}.put', [targetObj, indexVal, value], null);
            return;
          }
        }
        targetObj[indexVal] = value;
        return;
      }
    }
    if (ast is WatchStatement) {
      if (!checkReactive(ast.target)) {
        throw Exception('Watch target not found: :${ast.target}');
      }
      setReactive(ast.target, ast.body);
    }

    if (ast is FunctionDecl) {
      functions[ast.name] = ast;
    }
    if (ast is FunctionCall) {
      if (ast.callee case IdentifierNode idf) {
        if (idf.name == 'eval') {
          var code = execute(ast.arguments[0]) as String;
          var tokenizer = Tokenizer(code);
          tokenizer.tokenize();
          var parser = Parser(tokenizer);
          var parsedAst = parser.parse();
          dynamic lastResult;
          for (var node in (parsedAst as Programe).body) {
            lastResult = execute(node);
          }
          return lastResult;
        }

        FunctionDecl? func = functions[idf.name] as FunctionDecl?;
        if (func == null) {
          if (SysFunctions.functions.contains(idf.name)) {
            List evaluatedArgs =
                ast.arguments.map((arg) => execute(arg)).toList();

            return SysFunctions.execute(idf.name, evaluatedArgs);
          }
          throw 'Unexpected function call: ${idf.name}. The function is not defined';
        }

        if (ast.arguments.length != func.arguments.length) {
          throw Exception(
              'Function ${idf.name}: requires ${func.arguments.length} but got ${ast.arguments.length}');
        }

        pushScope(); //create local scope of variable

        for (var i = 0; i < ast.arguments.length; i++) {
          defineVar(func.arguments[i], execute(ast.arguments[i]));
        }

        for (Node function in func.body) {
          var result = execute(function);

          if (result is _ReturnClause) {
            if (func.returnType != null &&
                (RunTimeType.check(result.value)) !=
                    (func.returnType as IdentifierNode).name) {
              throw Exception(
                  'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}');
            }

            return result.value;
          }
        }

        popScope();
      } else if (ast.callee case MemberAccess member) {
        var rawObject = execute(member.object);

        if (rawObject is klassObject) {
          if (member.object is IdentifierNode) {
            var className = (member.object as IdentifierNode).name;
            var staticMethodKey = '$className.${member.property}';
            if (className == 'Timer' && member.property == 'periodic') {
              var ms = execute(ast.arguments[0]) as num;
              var funcName = execute(ast.arguments[1]) as String;
              Timer.periodic(Duration(milliseconds: ms.toInt()), (timer) {
                FunctionDecl? func = functions[funcName] as FunctionDecl?;
                if (func != null) {
                  pushScope();
                  for (Node function in func.body) {
                    var result = execute(function);
                    if (result is _ReturnClause) break;
                  }
                  popScope();
                } else {
                  print('Timer error: function $funcName not found');
                }
              });
              return null;
            }

            if (className == 'Timer' && member.property == 'delayed') {
              var ms = execute(ast.arguments[0]) as num;
              var funcName = execute(ast.arguments[1]) as String;
              Timer(Duration(milliseconds: ms.toInt()), () {
                FunctionDecl? func = functions[funcName] as FunctionDecl?;
                if (func != null) {
                  pushScope();
                  for (Node function in func.body) {
                    var result = execute(function);
                    if (result is _ReturnClause) break;
                  }
                  popScope();
                } else {
                  print('Timer error: function $funcName not found');
                }
              });
              return null;
            }

            if (Runtime.outerStaticMethods.containsKey(staticMethodKey)) {
              return Runtime.outerStaticMethods[staticMethodKey]!(
                  ast.arguments.map((e) => execute(e)).toList());
            }
          }

          FunctionDecl? func;
          for (var m in rawObject.methods) {
            if (m.name == member.property) {
              func = m;
              break;
            }
          }

          if (func != null && func.isStatic) {
            if (ast.arguments.length != func.arguments.length) {
              throw Exception(
                  'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}');
            }
            pushScope(); //create local scope of variable
            for (var i = 0; i < ast.arguments.length; i++) {
              defineVar(func.arguments[i], execute(ast.arguments[i]));
            }

            for (Node function in func.body) {
              var result = execute(function);

              if (result is _ReturnClause) {
                if (func.returnType != null &&
                    (RunTimeType.check(result.value)) !=
                        (func.returnType as IdentifierNode).name) {
                  throw Exception(
                      'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}');
                }

                popScope();
                return result.value;
              }
            }

            popScope();
            return null;
          }

          throw Exception(
              'Static method ${member.property} not found or is not natively registered');
        }

        if (rawObject is! KlassInstance) {
          String? className =
              Runtime.primitiveClassBindings[rawObject.runtimeType];
          if (className == null) {
            if (rawObject is String)
              className = 'String';
            else if (rawObject is num)
              className = 'Number';
            else if (rawObject is List)
              className = 'List';
            else if (rawObject is Map)
              className = 'Map';
            else if (rawObject is DateTime)
              className = 'DateTime';
            else
              throw Exception(
                  'No primitive class binding found for type ${rawObject.runtimeType}');
          }

          klassObject? primitiveClass = getGlobal(className) as klassObject?;
          if (primitiveClass == null)
            throw Exception('$className class not found.');
          FunctionDecl func = primitiveClass.methods.firstWhere(
              (m) => m.name == member.property,
              orElse: () => throw Exception(
                  'Method ${member.property} not found on $className'));

          if (ast.arguments.length != func.arguments.length) {
            throw Exception(
                'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}');
          }
          if (func.isOuter) {
            return Runtime.call(
                '$className.${func.name}',
                [rawObject, ...ast.arguments.map((e) => execute(e))],
                (func.returnType as IdentifierNode?)?.name);
          }
          throw Exception(
              'Only outer methods are supported on primitive bindings');
        }

        KlassInstance? object = rawObject as KlassInstance?;

        FunctionDecl func = object!.functions[member.property]!;

        if (ast.arguments.length != func.arguments.length) {
          throw Exception(
              'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}');
        }
        if (func.isOuter) {
          final String? returnType = (func.returnType as IdentifierNode?)?.name;
          return Runtime.call('${object.name}.${func.name}',
              [object, ...ast.arguments.map((e) => execute(e))], returnType);
        }

        pushScope(); //create local scope of variable
        currentThis = object;
        for (var i = 0; i < ast.arguments.length; i++) {
          defineVar(func.arguments[i], execute(ast.arguments[i]));
        }

        for (Node function in func.body) {
          var result = execute(function);

          if (result is _ReturnClause) {
            if (func.returnType != null &&
                (RunTimeType.check(result.value)) !=
                    (func.returnType as IdentifierNode).name) {
              throw Exception(
                  'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}');
            }

            return result.value;
          }
        }

        popScope();
      }
    }

    if (ast is MemberAccess) {
      var obj = execute(ast.object);

      if (obj is KlassInstance) {
        var val = obj.getField(ast.property);
        if (val != null) {
          // print('MemberAccess property=${ast.property}, value=$val');
          return val;
        }

        var getterKey = '${obj.name}.${ast.property}';
        if (Runtime.outerGetters.containsKey(getterKey)) {
          return Runtime.outerGetters[getterKey]!([obj]);
        }

        return null;
      }
      if (obj is klassObject) {
        if (ast.object is IdentifierNode) {
          var className = (ast.object as IdentifierNode).name;
          var staticFieldKey = '$className.${ast.property}';
          if (Runtime.outerStaticFields.containsKey(staticFieldKey)) {
            return Runtime.outerStaticFields[staticFieldKey];
          }
        }

        if (obj.getField(ast.property)?.isStatic == true) {
          dynamic staticField = obj.getStatic(ast.property);

          if (staticField != null) {
            return staticField;
            // return execute(staticField);
          }
        }
      }
    }
    if (ast is IdentifierNode) {
      return getVar(ast.name);
    }
    if (ast is ArrayNode) {
      var elements = ast.elements.map((e) => execute(e)).toList();
      klassObject? listClass = getGlobal('List') as klassObject?;
      if (listClass == null)
        throw Exception(
            'List class not found. Ensure core object.velv is imported.');
      var instance = listClass.instanciate('List', execute);
      instance.setField('_nativeData', elements);
      return instance;
    }
    if (ast is MapNode) {
      Map<dynamic, dynamic> map = {};
      ast.entries.forEach((k, v) {
        map[execute(k)] = execute(v);
      });
      klassObject? mapClass = getGlobal('Map') as klassObject?;
      if (mapClass == null)
        throw Exception(
            'Map class not found. Ensure core object.velv is imported.');
      var instance = mapClass.instanciate('Map', execute);
      instance.setField('_nativeData', map);
      return instance;
    }
    if (ast is IndexAccessNode) {
      var targetObj = execute(ast.target);
      var indexVal = execute(ast.index);
      if (targetObj is KlassInstance) {
        if (targetObj.functions.containsKey('get')) {
          return Runtime.call(
              '${targetObj.name}.get', [targetObj, indexVal], null);
        }
      }
      return targetObj[indexVal];
    }
    if (ast is Number) {
      return ast.value;
    }
    if (ast is StringNode) {
      return ast.value;
    }
    if (ast is VariableNode) {
      return getVar(ast.name);
    }
    if (ast is ThisNode) {
      return currentThis;
    }
    if (ast is ReturnNode) {
      return _ReturnClause(execute(ast.value));
    }

    if (ast is IfNode) {
      var result = execute(ast.condition);
      if (result == true) {
        pushScope();
        for (var c in ast.ifBlock) {
          var r = execute(c);
          if (r is _ReturnClause) {
            popScope();
            return r;
          }
        }
        popScope();
      }

      if (result == false && ast.elseNode != null) {
        for (var c in ast.elseNode!) {
          pushScope();
          var r = execute(c);
          popScope();
          if (r is _ReturnClause) {
            return r;
          }
        }
      }
    }
    if (ast is BooleanNode) {
      return ast.value;
    }
    if (ast is PrintNode) {
      if (ast.value == null) return;
      print(execute(ast.value!));
    }
    if (ast is LoopStatement) {
      int times = execute(ast.iterationTimes);
      for (var i = 0; i < times; i++) {
        pushScope();

        defineVar(ast.indexName ?? 'index', i);
        for (var j = 0; j < ast.body.length; j++) {
          execute(ast.body[j]);
        }
        popScope();
      }
    }
    if (ast is WhileNode) {
      while (execute(ast.condition) == true) {
        pushScope();
        for (var node in ast.body) {
          execute(node);
        }
        popScope();
      }
    }

    if (ast is ForNode) {
      pushScope();
      if (ast.init != null) {
        execute(ast.init!);
      }
      while (ast.condition == null || execute(ast.condition!) == true) {
        pushScope();
        for (var node in ast.body) {
          execute(node);
        }
        popScope();
        if (ast.update != null) {
          execute(ast.update!);
        }
      }
      popScope();
    }

    if (ast is TryCatchNode) {
      try {
        pushScope();
        for (var node in ast.tryBlock) {
          final res = execute(node);
          if (res != null) {
            popScope();
            return res;
          }
        }
        popScope();
      } catch (e) {
        popScope();
        pushScope();
        if (ast.catchVar != null) {
          // Strip 'Exception: ' if present, or just use string representation
          String errStr = e.toString();
          if (errStr.startsWith('Exception: ')) {
            errStr = errStr.substring(11);
          }
          // By default, Velvet throws strings
          defineVar(ast.catchVar!, errStr);
        }
        for (var node in ast.catchBlock) {
          final res = execute(node);
          if (res != null) {
            popScope();
            return res;
          }
        }
        popScope();
      }
    }

    if (ast is ThrowNode) {
      var value = execute(ast.expression);
      throw Exception(value.toString());
    }

    if (ast is ClassDeclration) {
      setGlobal(
        ast.name,
        klassObject(
            execute: execute,
            fields: ast.body.whereType<VariableDeclarationNode>().toList(),
            methods: ast.body.whereType<FunctionDecl>().toList()),
      );
    }
    if (ast is ImportNode) {
      var file = File(ast.path);
      if (!file.existsSync()) {
        // Try resolving from the core library directory
        var coreFile = File('bin/velvet_core/${ast.path}');
        if (coreFile.existsSync()) {
          file = coreFile;
        } else {
          throw Exception('Import file not found: ${ast.path}');
        }
      }
      Tokenizer tokenizer = Tokenizer(file.readAsStringSync())..tokenize();
      Programe parsed = Parser(tokenizer).parse();
      execute(parsed);
    }
    if (ast is NewClassInstance) {
      klassObject? klass = getGlobal(ast.name) as klassObject?;
      if (klass == null) {
        throw Exception('Class name ${ast.name} is not defined');
      }

      var instance = klass.instanciate(ast.name, execute);

      // Check for constructor
      FunctionDecl? initMethod;
      for (var m in klass.methods) {
        if (m.name == 'init') {
          initMethod = m;
          break;
        }
      }
      if (initMethod != null) {
        if (initMethod.isOuter) {
          Runtime.call('${ast.name}.init',
              [instance, ...ast.args.map((e) => execute(e))], null);
        } else {
          pushScope();
          var prevThis = currentThis;
          currentThis = instance;
          for (int i = 0; i < ast.args.length; i++) {
            if (i < initMethod.arguments.length) {
              defineVar(initMethod.arguments[i], execute(ast.args[i]));
            }
          }
          for (var node in initMethod.body) {
            execute(node);
          }
          currentThis = prevThis;
          popScope();
        }
      }

      return instance;
    }
    if (ast is KlassInstance) {}
  }

  expect(dynamic value, dynamic type) {}
}

class _ReturnClause {
  final dynamic value;
  _ReturnClause(this.value);
}
