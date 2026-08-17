import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  generateBindings(args);
}

void generateBindings(List<String> args) {
  if (args.isEmpty) {
    print('Usage: velvet bind <file_or_dir> [outDir]');
    exit(1);
  }

  final targetPath = args[0];
  final outDir = args.length > 1 ? args[1] : Directory.current.path;

  List<File> dartFiles = [];

  if (FileSystemEntity.isDirectorySync(targetPath)) {
    final dir = Directory(targetPath);
    dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();
  } else if (FileSystemEntity.isFileSync(targetPath)) {
    dartFiles = [File(targetPath)];
  } else {
    print('Path not found: $targetPath');
    exit(1);
  }

  final basename = FileSystemEntity.isDirectorySync(targetPath) 
      ? p.basename(targetPath) 
      : p.basenameWithoutExtension(targetPath);

  final velvContent = StringBuffer();
  final registryContent = StringBuffer();
  final imports = <String>{};

  registryContent.writeln("import 'package:velvet_cmp/runtime/runtime.dart';");

  final classRegistrations = StringBuffer();

  for (final file in dartFiles) {
    final source = file.readAsStringSync();
    final result = parseString(content: source);
    final unit = result.unit;

    bool hasValidClasses = false;

    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        final dartClassName = declaration.namePart.typeName.lexeme;
        if (dartClassName.startsWith('_')) continue; // Skip private classes

        hasValidClasses = true;
        final velvetClassName = dartClassName.replaceAll(RegExp(r'^_+'), '');
        
        velvContent.writeln("class $velvetClassName {");
        classRegistrations.writeln("    Runtime.register('$velvetClassName', (klass) {");

        for (final member in declaration.body.members) {
          if (member is MethodDeclaration) {
            final methodName = member.name.lexeme;
            if (methodName.startsWith('_')) continue; // skip private
            if (member.isOperator) continue; // skip operators

            final isStatic = member.isStatic;
            final isGetter = member.isGetter;
            final isSetter = member.isSetter;
            
            if (isGetter || isSetter) continue; // For now, focus on methods
            
            final params = member.parameters?.parameters.toList() ?? [];
            final paramNames = params.map((p) => p.name?.lexeme ?? '').join(', ');

            if (isStatic) {
               velvContent.writeln("    static outer fn $methodName($paramNames)");
               classRegistrations.writeln("      klass.defineStatic('$methodName', (args) {");
               final castedArgs = _generateArgs(params, true);
               classRegistrations.writeln("        return $dartClassName.$methodName($castedArgs);");
               classRegistrations.writeln("      });");
            } else {
               velvContent.writeln("    outer fn $methodName($paramNames)");
               classRegistrations.writeln("      klass.define('$methodName', (args) {");
               final castedArgs = _generateArgs(params, false);
               classRegistrations.writeln("        return (args[0] as $dartClassName).$methodName($castedArgs);");
               classRegistrations.writeln("      });");
            }
          }
        }
        
        velvContent.writeln("}\n");
        classRegistrations.writeln("    });");
      }
    }

    if (hasValidClasses) {
      imports.add("import 'file://${file.absolute.path}';");
    }
  }

  // Write all imports at the top
  for (final imp in imports) {
    registryContent.writeln(imp);
  }
  registryContent.writeln();

  registryContent.writeln("class ${capitalize(basename)}Registry {");
  registryContent.writeln("  static void register() {");
  registryContent.write(classRegistrations.toString());
  registryContent.writeln("  }");
  registryContent.writeln("}");

  // Write outputs
  final velvFile = File(p.join(outDir, '$basename.velv'));
  final registryFile = File(p.join(outDir, '${basename}_registry.dart'));

  velvFile.writeAsStringSync(velvContent.toString());
  registryFile.writeAsStringSync(registryContent.toString());

  print('Scanned ${dartFiles.length} files.');
  print('Generated ${velvFile.path}');
  print('Generated ${registryFile.path}');
}

String capitalize(String s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';

String _generateArgs(List<FormalParameter> params, bool isStatic) {
  final buffer = StringBuffer();
  int offset = isStatic ? 0 : 1; 
  for (var i = 0; i < params.length; i++) {
    final p = params[i];
    final isNamed = p.isNamed;
    final paramName = p.name?.lexeme;
    
    if (isNamed && paramName != null) {
      buffer.write('$paramName: ');
    }

    buffer.write('args.length > ${i + offset} ? args[${i + offset}] : null');
    
    if (i < params.length - 1) buffer.write(', ');
  }
  return buffer.toString();
}
