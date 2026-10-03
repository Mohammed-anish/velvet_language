import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main() {
  final coreDir = Directory('bin/velvet_core');
  if (!coreDir.existsSync()) {
    print('Could not find bin/velvet_core directory.');
    exit(1);
  }

  final files = coreDir.listSync().whereType<File>().where((f) => f.path.endsWith('.velv'));
  
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// Run `dart run tool/bundle_core.dart` to update this file.');
  buffer.writeln();
  buffer.writeln('class BundledCore {');
  buffer.writeln('  static const Map<String, String> files = {');

  for (final file in files) {
    final baseName = p.basenameWithoutExtension(file.path);
    final content = file.readAsStringSync();
    
    // Escape string for Dart source
    final escaped = jsonEncode(content);
    
    buffer.writeln("    '$baseName': $escaped,");
  }

  buffer.writeln('  };');
  buffer.writeln('}');

  final outDir = Directory('lib/core');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  File('lib/core/bundled_core.dart').writeAsStringSync(buffer.toString());
  print('Successfully generated lib/core/bundled_core.dart');
}
