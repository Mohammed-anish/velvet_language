import 'package:velvet_cmp/interpreter/scope.dart';
import 'package:velvet_cmp/interpreter/sys_functions.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/runtime/class_object.dart';
import 'package:velvet_cmp/runtime/external_registery.dart';
import 'package:velvet_cmp/runtime/runtime.dart';
import 'package:velvet_cmp/runtime/runtime_type.dart';

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
      for (final Node node in ast.body) {
        execute(node);
      }
    }

    if (ast is BineryNode) {
      var left = execute(ast.left);
      var op = ast.op;
      var right = execute(ast.right);

      if (op == '+') {
        return left + right;
      } else if (op == '-') {
        return left - right;
      } else if (op == '==') {
        return left == right;
      } else if (op == '>') {
        print('left is $left and $right');
        return left > right;
      }
    }
    if (ast is ExpressionStatement) {
      execute(ast.value);
    }

    if (ast is VariableDeclarationNode) {
      if (ast.kind != 'auto' &&
          ast.kind != RunTimeType.check(execute(ast.value))) {
        throw 'Variable needs ${ast.kind} but got ${RunTimeType.check(execute(ast.value))}';
      }
      setVar(ast.name, execute(ast.value));

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
          klass.setStatic(member.property, execute(ast.value));

          return;
        } else {
          KlassInstance? object = execute(member.object) as KlassInstance?;

          if (object!.has(member.property)) {
            final value = execute(ast.value);
            if ((RunTimeType.check(value)) !=
                object.instanceOf.getField(member.property)?.kind) {
              throw Exception(
                  'Expected value type ${object.instanceOf.getField(member.property)?.kind} but got ${(RunTimeType.check(value))}');
            }

            object.setField(member.property, value);
          } else {
            throw Exception('Invalid property!! ${member.property}');
          }
        }
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
          setVar(func.arguments[i], execute(ast.arguments[i]));
        }

        for (Node function in func.body) {
          var result = execute(function);

          if (result is _ReturnClause) {
            if ((RunTimeType.check(result.value)) !=
                (func.returnType as IdentifierNode).name) {
              throw Exception(
                  'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}');
            }

            return result.value;
          }
        }

        popScope();
      } else if (ast.callee case MemberAccess member) {
        KlassInstance? object = execute(member.object) as KlassInstance?;

        FunctionDecl func = object!.functions[member.property]!;

        if (ast.arguments.length != func.arguments.length) {
          throw Exception(
              'Function ${member.property}: requires ${func.arguments.length} but got ${ast.arguments.length}');
        }
        if (func.isOuter) {
          final String? returnType = (func.returnType as IdentifierNode?)?.name;
          return Runtime.call(
              '${object.name}.${func.name}',
              ast.arguments
                  .map(
                    (e) => execute(e),
                  )
                  .toList()
                  .cast(),
              returnType);
        }

        pushScope(); //create local scope of variable
        currentThis = object;
        for (var i = 0; i < ast.arguments.length; i++) {
          setVar(func.arguments[i], execute(ast.arguments[i]));
        }

        for (Node function in func.body) {
          var result = execute(function);

          if (result is _ReturnClause) {
            if ((RunTimeType.check(result.value)) !=
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
        return obj.getField(ast.property);
      }
      if (obj is klassObject) {
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
          execute(c);
        }
        popScope();
      }

      if (result == false && ast.elseNode != null) {
        for (var c in ast.elseNode!) {
          pushScope();
          execute(c);
          popScope();
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

        setVar(ast.indexName ?? 'index', i);
        for (var j = 0; j < ast.body.length; j++) {
          execute(ast.body[j]);
        }
        popScope();
      }
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
    if (ast is NewClassInstance) {
      klassObject? klass = getGlobal(ast.name) as klassObject?;
      if (klass == null) {
        throw Exception('Class name ${ast.name} is not defined');
      }

      return klass.instanciate(ast.name, execute);
    }
    if (ast is KlassInstance) {}
  }

  expect(dynamic value, dynamic type) {}
}

class _ReturnClause {
  final dynamic value;
  _ReturnClause(this.value);
}
