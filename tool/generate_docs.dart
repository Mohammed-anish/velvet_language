import 'dart:io';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';
import 'package:velvet_cmp/lsp/analyzer.dart';
import 'package:path/path.dart' as p;

void main() {
  final coreDir = Directory('bin/velvet_core');
  if (!coreDir.existsSync()) {
    print('Could not find bin/velvet_core');
    exit(1);
  }

  final files = coreDir.listSync().whereType<File>().where((f) => f.path.endsWith('.velv'));
  
  final buffer = StringBuffer();
  buffer.writeln('# Velvet Core Libraries');
  buffer.writeln();
  buffer.writeln('This document contains the complete documentation for all built-in core libraries in Velvet.');
  buffer.writeln();

  final Map<String, List<ClassDefinition>> moduleClasses = {};

  for (final file in files) {
    final moduleName = p.basenameWithoutExtension(file.path);
    final content = file.readAsStringSync();
    
    try {
      final tokenizer = Tokenizer(content)..tokenize();
      final parser = Parser(tokenizer);
      final program = parser.parse();
      
      final analyzer = Analyzer();
      analyzer.analyzeAST(program);
      
      if (analyzer.classes.isNotEmpty) {
        moduleClasses[moduleName] = analyzer.classes;
      }
    } catch (e) {
      print('Error parsing $moduleName: $e');
    }
  }

  final sortedModules = moduleClasses.keys.toList()..sort();

  for (final module in sortedModules) {
    buffer.writeln('## Module: `$module`');
    buffer.writeln('---\n');
    
    for (final clazz in moduleClasses[module]!) {
      buffer.writeln('### Class: `${clazz.name}`');
      if (clazz.docComment != null && clazz.docComment!.isNotEmpty) {
        buffer.writeln(clazz.docComment);
        buffer.writeln();
      }
      
      final fields = clazz.members.where((m) => !m.isMethod).toList();
      if (fields.isNotEmpty) {
        buffer.writeln('**Properties:**');
        for (final field in fields) {
          final isStatic = field.isStatic ? 'static ' : '';
          buffer.writeln('- `$isStatic${field.name}`');
        }
        buffer.writeln();
      }
      
      final methods = clazz.members.where((m) => m.isMethod).toList();
      if (methods.isNotEmpty) {
        buffer.writeln('**Methods:**');
        for (final method in methods) {
          final isStatic = method.isStatic ? 'static ' : '';
          buffer.writeln('- `$isStatic${method.name}(${method.parameters.join(', ')})`');
          if (method.docComment != null && method.docComment!.isNotEmpty) {
             buffer.writeln('  > ${method.docComment}');
          }
        }
        buffer.writeln();
      }
      
      buffer.writeln();
    }
  }

  final outFile = File('Velvet_Core_Documentation.md');
  outFile.writeAsStringSync(buffer.toString());
  print('Generated ${outFile.path}');
}
