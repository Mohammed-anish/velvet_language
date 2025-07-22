import 'package:velvet_cmp/interpreter/scope.dart';
import 'package:velvet_cmp/interpreter/sys_functions.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';

class Interpreter with Scopes {
  Map<String, Node> functions = {};

  dynamic execute(Node ast) {
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
      setVar(ast.name, execute(ast.value));

      if (ast.isReactive) {
        setEmptyReactive(ast.name);
      }
    }

    if (ast is AssignmentNode) {
      if (checkReactive(ast.variableName)) {
        notifyReactive(
          ast.variableName,
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
      setVar(ast.variableName, execute(ast.value));
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
      FunctionDecl? func = functions[ast.name] as FunctionDecl?;
      if (func == null) {
        if (SysFunctions.functions.contains(ast.name)) {
          List evaluatedArgs =
              ast.arguments.map((arg) => execute(arg)).toList();

          return SysFunctions.execute(ast.name, evaluatedArgs);
        }
        throw 'Unexpected function call: ${ast.name}. The function is not defined';
      }

      if (ast.arguments.length != func.arguments.length) {
        throw Exception(
            'Function ${ast.name}: requires ${func.arguments.length} but got ${ast.arguments.length}');
      }

      pushScope(); //create local scope of variable

      for (var i = 0; i < ast.arguments.length; i++) {
        setVar(func.arguments[i], execute(ast.arguments[i]));
      }

      for (Node function in func.body) {
        var result = execute(function);

        if (result is _ReturnClause) {
          if ((mapRuntimeTypeToCustomType(result.value)) !=
              (func.returnType as IdentifierNode).name) {
            throw Exception(
                'Expected return type is ${(func.returnType as IdentifierNode).name}. but got ${result.value}');
          }

          return result.value;
        }
      }

      popScope();
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
      for (var i = 0; i < ast.iterationTimes; i++) {
        pushScope();

        setVar(ast.indexName ?? 'index', i);
        for (var j = 0; j < ast.body.length; j++) {
          execute(ast.body[j]);
        }
        popScope();
      }
    }
  }

  String mapRuntimeTypeToCustomType(dynamic value) {
    var dartType = value.runtimeType.toString();

    const typeMap = {
      'String': 'str',
      'int': 'int',
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

class _ReturnClause {
  final dynamic value;
  _ReturnClause(this.value);
}
