import 'dart:io';

import 'package:velvet_cmp/interpreter/interpreter.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/parser.dart';

import 'package:velvet_cmp/runtime/runtime.dart';

bool isJsBuild = identical(1, 1.0);

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: velvet <script.velv>');
    return;
  }
  if (args.length > 1) {
    Runtime.scriptArgs = args.sublist(1);
  }
  
  File mainFile = File(args.first);
  Directory dir = mainFile.parent;
  if (dir.existsSync()) {
    var actionFiles = dir.listSync().where((f) => f.path.endsWith('.action.velv'));
    for (var file in actionFiles) {
      if (file is File) {
        Tokenizer actionTokenizer = Tokenizer(file.readAsStringSync())..tokenize();
        Parser(actionTokenizer).parse();
      }
    }
  }

  Tokenizer tokenizer = Tokenizer(read(args))..tokenize();
  // print(tokenizer.tokens.map((t) => t.type.name).join(', '));

  Programe parse = Parser(tokenizer).parse();
  // print(parse);
  try {
    await Interpreter().execute(parse);
  } on VelvetException catch (e) {
    print('\x1B[31m$e\x1B[0m'); // ANSI Red
    exit(1);
  } catch (e) {
    print('\x1B[31mUnhandled Native Exception: $e\x1B[0m');
    exit(1);
  }
}

read(List<String> args) {
  return File(args.first).readAsStringSync();
}
