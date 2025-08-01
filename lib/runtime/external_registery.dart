import 'dart:io';

import 'package:velvet_cmp/runtime/runtime.dart';

class OuterFunctionRegistry {
  static void register() {
    Runtime.resgister(
      "Person.exec",
      (args) {
        return 'exec called';
      },
    );
    Runtime.resgister(
      'File.open',
      (args) {
        return File(args.first);
      },
    );
    Runtime.resgister(
      'File.read',
      (args) {
        return '';
      },
    );
  }
}
