import 'dart:io';
import 'package:velvet_cmp/runtime/runtime.dart';


class SysFunctions {
  static List<String> functions = ['print', 'ofile', 'input', 'arg'];

  static execute(String name, List<dynamic> arguments) {
    if (name == 'print') {
      print(arguments.first);
    }
    if (name == 'input') {
      if (arguments.isNotEmpty) {
        stdout.write(arguments.first);
      }
      return stdin.readLineSync();
    }
    if (name == 'arg') {
      if (arguments.isEmpty) return Runtime.scriptArgs;
      var index = (arguments.first as num).toInt();
      if (index >= 0 && index < Runtime.scriptArgs.length) {
        return Runtime.scriptArgs[index];
      }
      return null;
    }
    if (name == 'ofile') {
      try {
        var file = File(arguments.first).readAsStringSync();

        return file;
      } catch (e) {
        throw 'Error $e';
      }
    }
  }
}
