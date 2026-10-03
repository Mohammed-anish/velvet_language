import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/vm/chunk.dart';
import 'package:velvet_cmp/vm/opcodes.dart';

class BytecodeCompiler {
  final Chunk chunk = Chunk();

  Chunk compile(Programe ast) {
    for (var stmt in ast.body) {
      _visitNode(stmt);
    }
    _emit(Opcode.ret, 0); // End of program
    return chunk;
  }

  void _visitNode(Node node) {
    int line = node.line ?? 0;

    if (node is Number) {
      _emitConstant(node.value, line);
    } else if (node is StringNode) {
      _emitConstant(node.value, line);
    } else if (node is BineryNode) {
      // Post-order traversal: left, right, operator
      _visitNode(node.left);
      _visitNode(node.right);
      
      switch (node.op) {
        case '+': _emit(Opcode.add, line); break;
        case '-': _emit(Opcode.subtract, line); break;
        case '*': _emit(Opcode.multiply, line); break;
        case '/': _emit(Opcode.divide, line); break;
        default: throw Exception("Unsupported operator ${node.op}");
      }
    } else if (node is ExpressionStatement) {
      _visitNode(node.value);
    } else if (node is FunctionCall) {
      if (node.callee is IdentifierNode && (node.callee as IdentifierNode).name == 'print') {
        for (var arg in node.arguments) {
           _visitNode(arg);
           _emit(Opcode.print, line);
        }
      } else {
        throw Exception("VM Compiler does not yet support arbitrary function calls");
      }
    } else {
      throw Exception("VM Compiler does not yet support node type: ${node.runtimeType}");
    }
  }

  void _emit(int opcode, int line) {
    chunk.write(opcode, line);
  }

  void _emitConstant(dynamic value, int line) {
    int index = chunk.addConstant(value);
    _emit(Opcode.constant, line);
    _emit(index, line); // Write the index as the next byte
  }
}
