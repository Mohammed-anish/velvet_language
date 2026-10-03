import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:velvet_cmp/core/bundled_core.dart';
import 'package:velvet_cmp/interpreter/scope.dart';
import 'package:velvet_cmp/interpreter/sys_functions.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/runtime/class_object.dart';
import 'package:velvet_cmp/runtime/external_registery.dart';
import 'package:velvet_cmp/runtime/runtime.dart';
import 'package:velvet_cmp/runtime/runtime_type.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';

class VelvetException implements Exception {
  final String message;
  final List<String> callStack;
  VelvetException(this.message, this.callStack);

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.writeln("VelvetException: $message");
    buffer.writeln("Stack Trace:");
    for (var frame in callStack) {
      buffer.writeln("  at $frame");
    }
    return buffer.toString();
  }
}

class Interpreter with Scopes {
  Map<String, Node> functions = {};
  KlassInstance? currentThis;
  final List<String> _importDirectories = [];
  final Set<String> _loadedImports = {};

  Interpreter({String? entryScriptPath}) {
    if (entryScriptPath != null) {
      _importDirectories.add(File(entryScriptPath).absolute.parent.path);
    }
    OuterFunctionRegistry.register();
  }

  File _resolveImport(String importPath) {
    final candidates = <String>[];
    if (p.isAbsolute(importPath)) {
      candidates.add(importPath);
    } else {
      // The most recently imported module owns relative imports.
      for (final directory in _importDirectories.reversed) {
        candidates.add(p.join(directory, importPath));
      }
      // Retain support for running scripts that intentionally import from CWD.
      candidates.add(importPath);
      // Bundled core modules must be resolved from the executable, not CWD.
      if (Platform.script.isScheme('file')) {
        candidates.add(
          p.join(
            File(Platform.script.toFilePath()).parent.path,
            'velvet_core',
            importPath,
          ),
        );
      } else {
        candidates.add(p.join('bin', 'velvet_core', importPath));
      }
    }

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file;
      }
    }
    throw Exception('Import file not found: $importPath');
  }

  Future<dynamic> execute(
    Node ast, {
    List<Map<String, dynamic>>? customScope,
  }) async {
    try {
      return await _executeImpl(ast, customScope: customScope);
    } catch (e) {
      if (e is VelvetException) {
        // Add file context to the stack trace for imports
        if (ast is ImportNode) {
          e.callStack.add(
            'import "${ast.path}" at line ${ast.line}:${ast.column}',
          );
        }
        rethrow;
      }
      String msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      // For imports, include the import path in the stack frame
      if (ast is ImportNode) {
        throw VelvetException(msg, [
          'import "${ast.path}" at line ${ast.line}:${ast.column}',
        ]);
      }
      throw VelvetException(msg, ['line ${ast.line}:${ast.column}']);
    }
  }

  Future<dynamic> _executeImpl(
    Node ast, {
    List<Map<String, dynamic>>? customScope,
  }) async {
    if (customScope != null) {
      scopes = customScope;
    }
    if (ast is Programe) {
      if (getGlobal('__object_loaded') == null) {
        scopes.first['__object_loaded'] = true;
        await execute(ImportNode(path: 'object.velv'));
      }
      for (final Node node in ast.body) {
        await execute(node);
      }
    }

    if (ast is BlockNode) {
      dynamic lastResult;
      for (final Node node in ast.statements) {
        lastResult = await execute(node);
        if (lastResult is _ReturnClause) {
          return lastResult;
        }
      }
      return lastResult;
    }

    if (ast is CallableBlockNode) {
      return ast; // Return the node itself so it can be passed as a variable and executed later
    }

    if (ast is BineryNode) {
      if (ast.op == '&&') {
        final left = await execute(ast.left);
        if (left == false) return false;
        return await execute(ast.right);
      }
      if (ast.op == '||') {
        final left = await execute(ast.left);
        if (left == true) return true;
        return await execute(ast.right);
      }

      final left = await execute(ast.left);
      final right = await execute(ast.right);
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
      var right = await execute(ast.right);
      if (ast.operator == '-') return -right;
      if (ast.operator == '!') return !right;
      throw Exception('Unknown unary operator: ${ast.operator}');
    }
    if (ast is ExpressionStatement) {
      await execute(ast.value);
    }

    if (ast is KeywordNode) {
      return ast.value;
    }
    if (ast is TypeNode) {
      return ast.name;
    }

    if (ast is VariableDeclarationNode) {
      if (ast.kind != 'auto' &&
          ast.kind != RunTimeType.check(await execute(ast.value))) {
        throw 'Variable needs ${ast.kind} but got ${RunTimeType.check(await execute(ast.value))}';
      }
      if (ast.isReactive) {
        setEmptyReactive(ast.name);
      }
      var value = await execute(ast.value);
      if (ast.isContext) {
        defineContextVar(ast.name, value);
      }
      defineVar(ast.name, value);
      return null;
    }
    if (ast case StaticField static) {
      static.target.setStatic(static.name, await execute(static.value));
    }

    if (ast is AssignmentNode) {
      if (ast.target case IdentifierNode idf) {
        if (checkReactive(idf.name)) {
          notifyReactive(idf.name, await execute(ast.value), (nodes) async {
            for (final Node node in nodes) {
              pushScope();
              await execute(node);
              popScope();
            }
          });
        }
        setVar(idf.name, await execute(ast.value));
      }
      if (ast.target case MemberAccess member) {
        if (await execute(member.object) case klassObject klass) {
          if (member.object is IdentifierNode) {
            var className = (member.object as IdentifierNode).name;
            var staticFieldKey = '$className.${member.property}';
            if (Runtime.outerStaticFields.containsKey(staticFieldKey)) {
              Runtime.outerStaticFields[staticFieldKey] = await execute(
                ast.value,
              );
              return;
            }
          }
          klass.setStatic(member.property, await execute(ast.value));

          return;
        } else {
          KlassInstance? object =
              await execute(member.object) as KlassInstance?;
          final value = await execute(ast.value);

          var setterKey = '${object!.name}.${member.property}';
          if (Runtime.outerSetters.containsKey(setterKey)) {
            Runtime.outerSetters[setterKey]!([object, value]);
            return;
          }

          if (object.has(member.property)) {
            var kind = object.instanceOf.getField(member.property)?.kind;
            if (kind != 'auto' && (RunTimeType.check(value)) != kind) {
              throw Exception(
                'Expected value type ${kind} but got ${(RunTimeType.check(value))}',
              );
            }

            object.setField(member.property, value);
          } else {
            throw Exception('Invalid property!! ${member.property}');
          }
        }
      }
      if (ast.target case IndexAccessNode indexNode) {
        var targetObj = await execute(indexNode.target);
        var indexVal = await execute(indexNode.index);
        var value = await execute(ast.value);
        if (targetObj is KlassInstance) {
          if (targetObj.functions.containsKey('set')) {
            Runtime.call(
                '${targetObj.name}.set',
                [
                  targetObj,
                  indexVal,
                  value,
                ],
                null);
            return;
          } else if (targetObj.functions.containsKey('put')) {
            Runtime.call(
                '${targetObj.name}.put',
                [
                  targetObj,
                  indexVal,
                  value,
                ],
                null);
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
          var code = await execute(ast.arguments[0]) as String;
          var tokenizer = Tokenizer(code);
          tokenizer.tokenize();
          var parser = Parser(tokenizer);
          var parsedAst = parser.parse();
          dynamic lastResult;
          for (var node in (parsedAst as Programe).body) {
            lastResult = await execute(node);
          }
          return lastResult;
        }

        FunctionDecl? func = functions[idf.name] as FunctionDecl?;
        if (func == null) {
          if (SysFunctions.functions.contains(idf.name)) {
            List evaluatedArgs = [];
            for (var arg in ast.arguments) {
              evaluatedArgs.add(await execute(arg));
            }

            return SysFunctions.execute(idf.name, evaluatedArgs);
          }

          dynamic varVal;
          try {
            varVal = getVar(idf.name);
          } catch (_) {}

          if (varVal is CallableBlockNode) {
            pushScope();
            try {
              for (Node statement in varVal.statements) {
                var result = await execute(statement);
                if (result is _ReturnClause) return result.value;
              }
              return null;
            } finally {
              popScope();
            }
          }

          throw 'Unexpected function call: ${idf.name}. The function is not defined';
        }

        if (ast.arguments.length != func.arguments.length) {
          throw Exception(
            'Function ${idf.name}: requires ${func.arguments.length} but got ${ast.arguments.length}',
          );
        }

        pushScope(); //create local scope of variable

        for (var i = 0; i < ast.arguments.length; i++) {
          defineVar(func.arguments[i], await execute(ast.arguments[i]));
        }

        try {
          for (Node function in func.body) {
            var result = await execute(function);

            if (result is _ReturnClause) {
              if (func.returnType != null &&
                  (RunTimeType.check(result.value)) !=
                      (func.returnType as IdentifierNode).name) {
                throw Exception(
                  'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}',
                );
              }

              return result.value;
            }
          }
        } catch (e) {
          String frame = '${idf.name}() line ${ast.line}:${ast.column}';
          if (e is VelvetException) {
            e.callStack.add(frame);
            rethrow;
          } else {
            String msg = e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : e.toString();
            throw VelvetException(msg, [frame]);
          }
        } finally {
          popScope();
        }
      } else if (ast.callee case MemberAccess member) {
        var rawObject = await execute(member.object);

        if (rawObject == null) {
          throw Exception(
            "Cannot call '${member.property}' on null. Check that the receiver is initialized before invoking this method.",
          );
        }

        if (rawObject is klassObject) {
          if (member.object is IdentifierNode) {
            var className = (member.object as IdentifierNode).name;
            var staticMethodKey = '$className.${member.property}';
            if (className == 'Timer' && member.property == 'periodic') {
              var ms = await execute(ast.arguments[0]) as num;
              var funcName = await execute(ast.arguments[1]) as String;
              Timer.periodic(Duration(milliseconds: ms.toInt()), (timer) async {
                FunctionDecl? func = functions[funcName] as FunctionDecl?;
                if (func != null) {
                  pushScope();
                  for (Node function in func.body) {
                    var result = await execute(function);
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
              var ms = await execute(ast.arguments[0]) as num;
              var funcName = await execute(ast.arguments[1]) as String;
              Timer(Duration(milliseconds: ms.toInt()), () async {
                FunctionDecl? func = functions[funcName] as FunctionDecl?;
                if (func != null) {
                  pushScope();
                  for (Node function in func.body) {
                    var result = await execute(function);
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
              List evaluatedArgs = [];
              for (var e in ast.arguments) {
                evaluatedArgs.add(await execute(e));
              }
              return Runtime.outerStaticMethods[staticMethodKey]!(
                evaluatedArgs,
              );
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
                'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}',
              );
            }
            pushScope(); //create local scope of variable
            for (var i = 0; i < ast.arguments.length; i++) {
              defineVar(func.arguments[i], await execute(ast.arguments[i]));
            }

            for (Node function in func.body) {
              var result = await execute(function);

              if (result is _ReturnClause) {
                if (func.returnType != null &&
                    (RunTimeType.check(result.value)) !=
                        (func.returnType as IdentifierNode).name) {
                  throw Exception(
                    'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}',
                  );
                }

                popScope();
                return result.value;
              }
            }

            popScope();
            return null;
          }

          throw Exception(
            'Static method ${member.property} not found or is not natively registered',
          );
        }

        if (rawObject is! KlassInstance) {
          String? className =
              Runtime.primitiveClassBindings[rawObject.runtimeType];
          if (className == null) {
            for (var entry in Runtime.primitiveTypeChecks) {
              if (entry.key(rawObject)) {
                className = entry.value;
                break;
              }
            }
          }
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
                'No primitive class binding found for type ${rawObject.runtimeType}',
              );
          }

          klassObject? primitiveClass = getGlobal(className) as klassObject?;
          if (primitiveClass == null)
            throw Exception('$className class not found.');
          FunctionDecl func = primitiveClass.methods.firstWhere(
            (m) => m.name == member.property,
            orElse: () => throw Exception(
              'Method ${member.property} not found on $className',
            ),
          );

          if (ast.arguments.length != func.arguments.length) {
            throw Exception(
              'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}',
            );
          }
          if (func.isOuter) {
            List evaluatedArgs = [];
            for (var e in ast.arguments) {
              evaluatedArgs.add(await execute(e));
            }
            return Runtime.call(
              '$className.${func.name}',
              [rawObject, ...evaluatedArgs],
              (func.returnType as IdentifierNode?)?.name,
            );
          }
          throw Exception(
            'Only outer methods are supported on primitive bindings',
          );
        }

        KlassInstance? object = rawObject as KlassInstance?;

        FunctionDecl func = object!.functions[member.property]!;

        if (ast.arguments.length != func.arguments.length) {
          throw Exception(
            'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}',
          );
        }
        if (func.isOuter) {
          final String? returnType = (func.returnType as IdentifierNode?)?.name;
          List evaluatedArgs = [];
          for (var e in ast.arguments) {
            evaluatedArgs.add(await execute(e));
          }
          return Runtime.call(
              '${object.name}.${func.name}',
              [
                object,
                ...evaluatedArgs,
              ],
              returnType);
        }

        pushScope(); //create local scope of variable
        currentThis = object;
        for (var i = 0; i < ast.arguments.length; i++) {
          defineVar(func.arguments[i], await execute(ast.arguments[i]));
        }

        for (Node function in func.body) {
          var result = await execute(function);

          if (result is _ReturnClause) {
            if (func.returnType != null &&
                (RunTimeType.check(result.value)) !=
                    (func.returnType as IdentifierNode).name) {
              throw Exception(
                'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}',
              );
            }

            return result.value;
          }
        }

        popScope();
      }
    }

    if (ast is MemberAccess) {
      var obj = await execute(ast.object);

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
            // return await execute(staticField);
          }
        }
      }

      // Check primitive bindings
      var className = Runtime.primitiveClassBindings[obj.runtimeType];
      if (className == null) {
        for (var entry in Runtime.primitiveTypeChecks) {
          if (entry.key(obj)) {
            className = entry.value;
            break;
          }
        }
      }

      if (className != null) {
        var getterKey = '$className.${ast.property}';
        if (Runtime.outerGetters.containsKey(getterKey)) {
          return Runtime.outerGetters[getterKey]!([obj]);
        }
      }
    }
    if (ast is IdentifierNode) {
      return getVar(ast.name);
    }
    if (ast is ArrayNode) {
      var elements = [];
      for (var e in ast.elements) {
        elements.add(await execute(e));
      }
      klassObject? listClass = getGlobal('List') as klassObject?;
      if (listClass == null)
        throw Exception(
          'List class not found. Ensure core object.velv is imported.',
        );
      var instance = await listClass.instanciate('List', execute);
      instance.setField('_nativeData', elements);
      return instance;
    }
    if (ast is MapNode) {
      Map<dynamic, dynamic> map = {};
      for (var entry in ast.entries.entries) {
        map[await execute(entry.key)] = await execute(entry.value);
      }
      klassObject? mapClass = getGlobal('Map') as klassObject?;
      if (mapClass == null)
        throw Exception(
          'Map class not found. Ensure core object.velv is imported.',
        );
      var instance = await mapClass.instanciate('Map', execute);
      instance.setField('_nativeData', map);
      return instance;
    }
    if (ast is IndexAccessNode) {
      var targetObj = await execute(ast.target);
      var indexVal = await execute(ast.index);
      if (targetObj is KlassInstance) {
        if (targetObj.functions.containsKey('get')) {
          return Runtime.call(
              '${targetObj.name}.get',
              [
                targetObj,
                indexVal,
              ],
              null);
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
      return _ReturnClause(await execute(ast.value));
    }

    if (ast is IfNode) {
      var result = await execute(ast.condition);
      if (result == true) {
        pushScope();
        for (var c in ast.ifBlock) {
          var r = await execute(c);
          if (r is _ReturnClause) {
            popScope();
            return r;
          }
        }
        popScope();
      }

      if (result == false && ast.elseNode != null) {
        pushScope();
        for (var c in ast.elseNode!) {
          var r = await execute(c);
          if (r is _ReturnClause) {
            popScope();
            return r;
          }
        }
        popScope();
      }
    }
    if (ast is BooleanNode) {
      return ast.value;
    }
    if (ast is PrintNode) {
      if (ast.value == null) return;
      print(await execute(ast.value!));
    }
    if (ast is LoopStatement) {
      int times = await execute(ast.iterationTimes);
      for (var i = 0; i < times; i++) {
        pushScope();

        defineVar(ast.indexName ?? 'index', i);
        for (var j = 0; j < ast.body.length; j++) {
          await execute(ast.body[j]);
        }
        popScope();
      }
    }
    if (ast is WhileNode) {
      while (await execute(ast.condition) == true) {
        pushScope();
        for (var node in ast.body) {
          await execute(node);
        }
        popScope();
      }
    }

    if (ast is ForNode) {
      pushScope();
      if (ast.init != null) {
        await execute(ast.init!);
      }
      while (ast.condition == null || await execute(ast.condition!) == true) {
        pushScope();
        for (var node in ast.body) {
          await execute(node);
        }
        popScope();
        if (ast.update != null) {
          await execute(ast.update!);
        }
      }
      popScope();
    }

    if (ast is TryCatchNode) {
      try {
        pushScope();
        for (var node in ast.tryBlock) {
          final res = await execute(node);
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
          final res = await execute(node);
          if (res != null) {
            popScope();
            return res;
          }
        }
        popScope();
      }
    }

    if (ast is AwaitNode) {
      return await execute(ast.expression);
    }

    if (ast is ThrowNode) {
      var value = await execute(ast.expression);
      throw Exception(value.toString());
    }

    if (ast is RequiresContextNode) {
      for (var v in ast.variables) {
        try {
          var val = getContextVar(v);
          defineVar(v, val);
        } catch (e) {
          throw Exception(
            'Context variable "$v" is required but was not provided as a context in the calling environment.',
          );
        }
      }
      return null;
    }

    if (ast is ClassDeclration) {
      var klass = klassObject(
        fields: ast.body.whereType<VariableDeclarationNode>().toList(),
        methods: ast.body.whereType<FunctionDecl>().toList(),
      );
      setGlobal(ast.name, klass);
      await klass.initStatics(execute);
    }
    if (ast is StateDeclration) {
      var stateFields = ast.values
          .map(
            (val) => VariableDeclarationNode(
              name: val,
              kind: 'auto',
              value: StringNode(val),
              isStatic: true,
              isField: true,
              isReactive: false,
            ),
          )
          .toList();
      var stateKlass = klassObject(fields: stateFields, methods: []);
      for (var val in ast.values) {
        stateKlass.setStatic(val, val); // Set value to string representation
      }
      setGlobal(ast.name, stateKlass);
    }
    if (ast is ImportNode) {
      if (_loadedImports.contains(ast.path)) {
        return;
      }
      _loadedImports.add(ast.path);

      try {
        var file = _resolveImport(ast.path);
        final currentImportDir =
            _importDirectories.isEmpty ? null : _importDirectories.last;
        _importDirectories.add(file.parent.absolute.path);

        try {
          Tokenizer tokenizer = Tokenizer(file.readAsStringSync())..tokenize();
          Programe parsed = Parser(
            tokenizer,
            sourceName: p.basename(file.path),
          ).parse();
          await execute(parsed);
        } finally {
          _importDirectories.removeLast();
        }
      } catch (e) {
        // Don't swallow syntax/runtime errors from the imported file
        if (e is VelvetException) rethrow;
        if (BundledCore.files.containsKey(ast.path.replaceAll('.velv', ''))) {
          Tokenizer tokenizer = Tokenizer(
            BundledCore.files[ast.path.replaceAll('.velv', '')]!,
          )..tokenize();
          Programe parsed = Parser(tokenizer, sourceName: ast.path).parse();
          await execute(parsed);
        } else {
          rethrow;
        }
      }
    }
    if (ast is NewClassInstance) {
      klassObject? klass = getGlobal(ast.name) as klassObject?;
      if (klass == null) {
        throw Exception('Class name ${ast.name} is not defined');
      }

      var instance = await klass.instanciate(ast.name, execute);

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
          List evaluatedArgs = [];
          for (var e in ast.args) {
            evaluatedArgs.add(await execute(e));
          }
          Runtime.call('${ast.name}.init', [instance, ...evaluatedArgs], null);
        } else {
          pushScope();
          var prevThis = currentThis;
          currentThis = instance;
          for (int i = 0; i < ast.args.length; i++) {
            if (i < initMethod.arguments.length) {
              defineVar(initMethod.arguments[i], await execute(ast.args[i]));
            }
          }
          for (var node in initMethod.body) {
            await execute(node);
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
