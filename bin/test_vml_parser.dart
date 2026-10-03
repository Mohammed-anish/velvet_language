import 'dart:io';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';

void main() {
  String source = File('/tmp/test_vml.velv').readAsStringSync();
  var tokenizer = Tokenizer(source);
  tokenizer.tokenize();
  var parser = Parser(tokenizer);
  var ast = parser.parse();
  print(ast);
}
