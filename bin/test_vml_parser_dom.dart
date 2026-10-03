import 'dart:io';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';
import 'package:velvet_cmp/core/vml_dom.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';

void main() {
  String source = File('/tmp/test_vml.velv').readAsStringSync();
  var tokenizer = Tokenizer(source);
  tokenizer.tokenize();
  var parser = Parser(tokenizer, sourceName: 'test.vml');
  var ast = parser.parse();
  
  // Extract MarkupNodes from AST
  List<Node> markupNodes = [];
  for (var stmt in ast.body) {
    if (stmt is MarkupNode) {
      markupNodes.add(stmt);
    } else if (stmt is ExpressionStatement && stmt.value is MarkupNode) {
      markupNodes.add(stmt.value);
    }
  }
  
  var dom = VmlDocument.fromAst(markupNodes);
  print(dom.toString());
}
