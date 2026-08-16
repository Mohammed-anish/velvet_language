import 'dart:io';

void main() {
  final file = File('lib/interpreter/interpreter.dart');
  String content = file.readAsStringSync();
  
  // Replace definition
  content = content.replaceAll(
    'dynamic execute(Node ast, {List<Map<String, dynamic>>? customScope}) {',
    'Future<dynamic> execute(Node ast, {List<Map<String, dynamic>>? customScope}) async {'
  );

  // Replace calls
  // `execute(...)` -> `await execute(...)`
  // We need a regex that matches `execute(` but not `Future<dynamic> execute(` or `await execute(`
  // Also be careful not to replace `execute:` which is a parameter name.
  
  final regex = RegExp(r'(?<!await |execute: |Future<dynamic> )execute\(');
  content = content.replaceAll(regex, 'await execute(');
  
  file.writeAsStringSync(content);
  print('Refactored interpreter.dart');
}
