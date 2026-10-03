import 'package:test/test.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/action_registry.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/parser.dart';

Programe parse(String source) {
  ActionRegistry().clear();
  final tokenizer = Tokenizer(source)..tokenize();
  return Parser(tokenizer).parse();
}

void main() {
  test('captures and expands a statement', () {
    final program = parse('''
actions {
  wrap(statement: statement) { statement }
}
wrap print("hello")
''');

    final expansion = program.body.single as BlockNode;
    expect(expansion.statements.single, isA<ExpressionStatement>());
    final call = (expansion.statements.single as ExpressionStatement).value;
    expect(call, isA<FunctionCall>());
  });

  test('captures a keyword as a literal syntax value', () {
    final program = parse('''
actions {
  show(word: keyword) { print(word) }
}
show return
''');

    final expansion = program.body.single as BlockNode;
    final call = (expansion.statements.single as ExpressionStatement).value
        as FunctionCall;
    expect(call.arguments.single, isA<KeywordNode>());
    expect((call.arguments.single as KeywordNode).value, 'return');
  });

  test('substitutes type and parameter captures into declarations', () {
    final program = parse('''
actions {
  declare(type: type, value: expression) { type result = value }
  define(parameters: parameters, body: block) {
    fn generated(parameters) { body }
  }
}
declare Number 7
define (first, second) { print(first) }
''');

    final declaration = (program.body[0] as BlockNode).statements.single
        as VariableDeclarationNode;
    expect(declaration.kind, 'Number');

    final function =
        (program.body[1] as BlockNode).statements.single as FunctionDecl;
    expect(function.arguments, ['first', 'second']);
    expect(function.body.single, isA<ExpressionStatement>());
  });
}
