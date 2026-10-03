class Opcode {
  static const int constant = 0; // Load constant from pool
  static const int add = 1;
  static const int subtract = 2;
  static const int multiply = 3;
  static const int divide = 4;
  static const int print = 5;    // Pop and print
  static const int ret = 6;      // Return from VM
}
