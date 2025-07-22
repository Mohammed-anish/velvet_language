import 'package:velvet_cmp/core/types.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';

abstract class CoreParser {
  final Tokenizer tokenizer;
  List<Token> tokens = [];
  int i = 0;

  CoreParser(this.tokenizer) {
    tokens = tokenizer.tokens;
  }

  Programe parse();

  Token? eat(
    TType type, {
    bool? isOptional,
    String? exeption,
  }) {
    //skip newlines if not intentially eated
    if (type != TType.newLine) {
      while (match(TType.newLine)) {
        advance();
      }
    }

    final c = current();

    if (c.type == type) {
      return advance();
    } else {
      if (isOptional == true) {
        return null;
      }
    }
    throw Exception(exeption ??
        'Unexpected token in expression: ${current().type}, expected: $type');
  }

  void eatNewLines() {
    while (current().type == TType.newLine) {
      advance();
    }
  }

  Token? getNext() {
    if (isEof()) return null;
    return tokens[i + 1];
  }

  Token current() {
    return tokens[i];
  }

  bool isEof() {
    return i >= tokens.length || current().type == TType.eof;
  }

  Token? advance() {
    if (isEof()) return null;
    return tokens[i++];
  }

  Token previous() {
    return tokens[i - 1];
  }

  bool match(TType type) {
    if (current().type == type) {
      return true;
    }
    return false;
  }

  bool matchNext(TType type) {
    if (tokens[i + 1].type == type) {
      return true;
    }
    return false;
  }

  bool matchAndEat(TType type) {
    if (current().type == type) {
      eat(type);
      return true;
    }
    return false;
  }

  Token? eatAny(List<TType> types) {
    if (types.contains(current().type)) {
      return advance();
    }
    return null;
  }

  bool anyMatch(List<TType> types) {
    if (types.contains(current().type)) {
      return true;
    }
    return false;
  }
}
