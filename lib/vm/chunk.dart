class Chunk {
  List<int> code = [];
  List<dynamic> constants = [];
  List<int> lines = []; // Store line numbers parallel to code array for debugging

  // Write an instruction or operand
  void write(int byte, int line) {
    code.add(byte);
    lines.add(line);
  }

  // Add a constant and return its index
  int addConstant(dynamic value) {
    constants.add(value);
    return constants.length - 1;
  }
}
