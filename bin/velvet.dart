import 'dart:io';

import 'package:velvet_cmp/interpreter/interpreter.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/parser.dart';

import 'package:velvet_cmp/runtime/runtime.dart';
import 'velvet_gen.dart';

bool isJsBuild = identical(1, 1.0);

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: velvet <script.velv> OR velvet bind <file_or_dir>');
    return;
  }

  if (args[0] == 'bind') {
    generateBindings(args.sublist(1));
    return;
  }
  if (args.length > 1) {
    Runtime.scriptArgs = args.sublist(1);
  }

  File mainFile = File(args.first);
  Directory dir = mainFile.parent;
  if (dir.existsSync()) {
    var actionFiles = dir.listSync().where(
      (f) => f.path.endsWith('.action.velv'),
    );
    for (var file in actionFiles) {
      if (file is File) {
        Tokenizer actionTokenizer = Tokenizer(file.readAsStringSync())
          ..tokenize();
        Parser(actionTokenizer).parse();
      }
    }
  }

  Tokenizer tokenizer = Tokenizer(read(args))..tokenize();
  // print(tokenizer.tokens.map((t) => t.type.name).join(', '));

  Programe parse;
  try {
    parse = Parser(
      tokenizer,
      sourceName: mainFile.uri.pathSegments.last,
    ).parse();
  } catch (e) {
    String msg = e.toString().replaceFirst('Exception: ', '');
    print('\x1B[31m$msg\x1B[0m');
    exit(1);
  }

  // print(parse);
  try {
    await Interpreter(entryScriptPath: mainFile.absolute.path).execute(parse);
  } on VelvetException catch (e) {
    // Strip nested "Exception: " wrappers for clean output
    String msg = e.message.replaceFirst('Exception: ', '');
    print('\x1B[31m$msg\x1B[0m');
    exit(1);
  } catch (e, s) {
    print('\x1B[31mUnhandled Native Exception: $e\n$s\x1B[0m');
    exit(1);
  }
}

read(List<String> args) {
  return File(args.first).readAsStringSync();
}
