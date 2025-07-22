import 'dart:io';

import 'package:velvet_cmp/parser/ast_classes.dart';

class SysFunctions {
  static List<String> functions = ['print', 'ofile'];

  static execute(String name, List<dynamic> arguments) {
    if (name == 'print') {
      print(arguments.first);
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
