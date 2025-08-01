import 'dart:io';

import 'package:velvet_cmp/interpreter/interpreter.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/parser.dart';

bool isJsBuild = identical(1, 1.0);

void main(List<String> args) {
  Tokenizer tokenizer = Tokenizer(read(args))..tokenize();
  // print(tokenizer.tokens);

  Programe parse = Parser(tokenizer).parse();
  // print(parse);
  Interpreter().execute(parse);
}

read(List<String> args) {
  return File(args.first).readAsStringSync();
}
