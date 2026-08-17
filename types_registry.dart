import 'package:velvet_cmp/runtime/runtime.dart';
import 'file:///Users/muzammil-sumra/Documents/Makings/VelvPlugin/velvet_language/lib/core/types.dart';

class TypesRegistry {
  static void register() {
    Runtime.register('Token', (klass) {
      klass.define('toString', (args) {
        return (args[0] as Token).toString();
      });
    });
  }
}
