import 'dart:io';
void main() { 
  var f = File('lib/bindings/uuid/uuid_registry.dart'); 
  var content = f.readAsStringSync(); 
  content = content.replaceAll(RegExp(r'file:///.*/uuid-4.6.0/lib/'), 'package:uuid/'); 
  content = content.replaceAll('class LibRegistry', 'class UuidRegistry'); 
  f.writeAsStringSync(content); 
}
