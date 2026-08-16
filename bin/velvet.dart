import 'dart:io';

import 'package:velvet_cmp/interpreter/interpreter.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/parser.dart';

import 'package:velvet_cmp/runtime/runtime.dart';

bool isJsBuild = identical(1, 1.0);

void main(List<String> args) async {
  if (args.length > 1) {
    Runtime.scriptArgs = args.sublist(1);
  }
  Tokenizer tokenizer = Tokenizer(read(args))..tokenize();
  // print(tokenizer.tokens.map((t) => t.type.name).join(', '));

  Programe parse = Parser(tokenizer).parse();
  // print(parse);
  await Interpreter().execute(parse);
}

read(List<String> args) {
  return File(args.first).readAsStringSync();
}
