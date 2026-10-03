import 'package:velvet_cmp/vm/chunk.dart';
import 'package:velvet_cmp/vm/opcodes.dart';

class VM {
  late Chunk chunk;
  int ip = 0; // Instruction Pointer
  List<dynamic> stack = [];

  void run(Chunk compiledChunk) {
    chunk = compiledChunk;
    ip = 0;
    stack.clear();

    while (true) {
      int instruction = _readByte();
      switch (instruction) {
        case Opcode.ret:
          return; // Exit VM loop

        case Opcode.constant:
          dynamic constant = _readConstant();
          _push(constant);
          break;

        case Opcode.add:
          dynamic b = _pop();
          dynamic a = _pop();
          _push(a + b);
          break;

        case Opcode.subtract:
          dynamic b = _pop();
          dynamic a = _pop();
          _push(a - b);
          break;

        case Opcode.multiply:
          dynamic b = _pop();
          dynamic a = _pop();
          _push(a * b);
          break;

        case Opcode.divide:
          dynamic b = _pop();
          dynamic a = _pop();
          _push(a / b);
          break;

        case Opcode.print:
          dynamic value = _pop();
          print(value);
          break;

        default:
          throw Exception("Unknown opcode: $instruction");
      }
    }
  }

  int _readByte() {
    return chunk.code[ip++];
  }

  dynamic _readConstant() {
    return chunk.constants[_readByte()];
  }

  void _push(dynamic value) {
    stack.add(value);
  }

  dynamic _pop() {
    return stack.removeLast();
  }
}
