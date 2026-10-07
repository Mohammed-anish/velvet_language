import 'dart:io';

import 'package:velvet_cmp/core/types.dart';

class Tokenizer {
  final String source;
  int index = 0;
  int line = 1;
  int column = 1;
  final List<Token> tokens = [];
  final List<Token> comments = [];

  Tokenizer(this.source);

  bool get isAtEnd => index >= source.length;
  String get current => isAtEnd ? '\u0000' : source[index];

  void advance() {
    if (current == '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }
    index++;
  }

  void addToken(TType type, [String? value, int? tokenLine, int? tokenColumn]) {
    tokens.add(Token(type, value ?? current, tokenLine ?? line, tokenColumn ?? column));
  }

  int parenDepth = 0;

  void tokenize() {
    while (!isAtEnd) {
      final char = current;
      final startLine = line;
      final startColumn = column;

      if (_isWhitespace(char)) {
        if (char == '\n' && parenDepth == 0) {
          addToken(TType.newLine, '\\n', startLine, startColumn);
        }
        advance();
      } else if (_isAlpha(char)) {
        _identifierOrKeyword(startLine, startColumn);
      } else if (_isDigit(char)) {
        _number(startLine, startColumn);
      } else if (char == '"' || char == "'") {
        _string(char, startLine, startColumn);
      } else if (char == '}' && interpolationDepth > 0) {
        addToken(TType.rParen, ')', startLine, startColumn);
        addToken(TType.plus, '+', startLine, startColumn);
        interpolationDepth--;
        _string(quoteStack.removeLast(), startLine, startColumn, isResume: true);
      } else {
        switch (char) {
          case '(':
            parenDepth++;
            addToken(TType.lParen, null, startLine, startColumn);
            break;
          case ')':
            if (parenDepth > 0) parenDepth--;
            addToken(TType.rParen, null, startLine, startColumn);
            break;
          case '{':
            addToken(TType.lBrace, null, startLine, startColumn);
            break;
          case '}':
            addToken(TType.rBrace, null, startLine, startColumn);
            break;
          case '#':
            addToken(TType.hash, '#', startLine, startColumn);
            break;
          case '[':
            addToken(TType.lBracket, null, startLine, startColumn);
            break;
          case ']':
            addToken(TType.rBracket, null, startLine, startColumn);
            break;
          case '.':
            addToken(TType.dot, null, startLine, startColumn);
            break;
          case '@':
            addToken(TType.at, null, startLine, startColumn);
            break;

          case ',':
            addToken(TType.comma, null, startLine, startColumn);
            break;
          case ':':
            addToken(TType.colon, null, startLine, startColumn);
            break;
          case ';':
            addToken(TType.semicolon, null, startLine, startColumn);
            break;
          case '+':
            _match('=')
                ? addToken(TType.plusAssign, '+=', startLine, startColumn)
                : addToken(TType.plus, null, startLine, startColumn);
            break;
          case '-':
            if (_match('=')) {
              addToken(TType.minusAssign, '-=', startLine, startColumn);
            } else if (_match('>')) {
              addToken(TType.arrow, '->', startLine, startColumn);
            } else {
              addToken(TType.minus, null, startLine, startColumn);
            }
            break;
          case '*':
            _match('=')
                ? addToken(TType.starAssign, '*=', startLine, startColumn)
                : addToken(TType.star, null, startLine, startColumn);
            break;
          case '/':
            if (_match('/')) {
              _comment(startLine, startColumn);
            } else if (_match('=')) {
              addToken(TType.slashAssign, '/=', startLine, startColumn);
            } else {
              addToken(TType.slash, null, startLine, startColumn);
            }
            break;
          case '=':
            _match('=')
                ? addToken(TType.doubleEqual, '==', startLine, startColumn)
                : addToken(TType.assign, null, startLine, startColumn);
            break;
          case '!':
            _match('=') ? addToken(TType.notEqual, '!=', startLine, startColumn) : addToken(TType.bang, null, startLine, startColumn);
            break;
          case '>':
            _match('=')
                ? addToken(TType.greaterEqual, '>=', startLine, startColumn)
                : addToken(TType.greater, null, startLine, startColumn);
            break;
          case '<':
            _match('=')
                ? addToken(TType.lessEqual, '<=', startLine, startColumn)
                : addToken(TType.less, null, startLine, startColumn);
            break;
          case '&':
            if (_match('&')) addToken(TType.and_, '&&', startLine, startColumn);
            break;
          case '|':
            if (_match('|')) addToken(TType.or_, '||', startLine, startColumn);
            break;
          default:
            // stdout is the LSP transport when the tokenizer runs in the
            // language server.  Never write diagnostics there.
            stderr.writeln("Unexpected char: $char");
        }
        advance();
      }
    }

    addToken(TType.eof, '', line, column);
    _stripContinuationNewlines();
  }

  /// Removes newline tokens when context indicates expression continuation.
  /// A newline is removed if:
  ///   - The previous meaningful token is a trailing operator/delimiter
  ///     (e.g., `+`, `*`, `/`, `=`, `,`, `(`, `[`, `&&`, `||`)
  ///   - The next meaningful token is a leading binary operator
  ///     (e.g., `+`, `*`, `/`, `&&`, `||` — but NOT `-` to avoid unary ambiguity)
  void _stripContinuationNewlines() {
    // Token types that, when trailing a line, mean the expression continues
    const trailingContinuation = {
      TType.plus,
      TType.minus,
      TType.star,
      TType.slash,
      TType.percent,
      TType.assign,
      TType.comma,
      TType.lParen,
      TType.lBracket,
      TType.and_,
      TType.or_,
      TType.equal,
      TType.doubleEqual,
      TType.notEqual,
      TType.greater,
      TType.greaterEqual,
      TType.less,
      TType.lessEqual,
      TType.dot,
    };

    // Token types that, when leading the next line, mean it's a continuation
    // NOTE: minus is excluded to avoid ambiguity with unary negation
    const leadingContinuation = {
      TType.plus,
      TType.star,
      TType.slash,
      TType.percent,
      TType.and_,
      TType.or_,
      TType.dot,
    };

    final filtered = <Token>[];
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].type != TType.newLine) {
        filtered.add(tokens[i]);
        continue;
      }

      // Find previous meaningful token (skip other newlines)
      Token? prev;
      for (var j = filtered.length - 1; j >= 0; j--) {
        if (filtered[j].type != TType.newLine) {
          prev = filtered[j];
          break;
        }
      }

      // Find next meaningful token (skip other newlines)
      Token? next;
      for (var k = i + 1; k < tokens.length; k++) {
        if (tokens[k].type != TType.newLine) {
          next = tokens[k];
          break;
        }
      }

      // Remove newline if previous token is a trailing continuation
      if (prev != null && trailingContinuation.contains(prev.type)) {
        continue; // skip this newline
      }

      // Remove newline if next token is a leading continuation
      if (next != null && leadingContinuation.contains(next.type)) {
        continue; // skip this newline
      }

      filtered.add(tokens[i]);
    }

    tokens.clear();
    tokens.addAll(filtered);
  }

  void _identifierOrKeyword(int startLine, int startColumn) {
    final start = index;
    while (!_isAtEndOrInvalid(current)) {
      advance();
    }
    final text = source.substring(start, index);

    final keywords = {
      'fn': TType.fn,
      'if': TType.if_,
      'else': TType.else_,
      'while': TType.while_,
      'for': TType.for_,
      'return': TType.return_,
      'break': TType.break_,
      'continue': TType.continue_,
      'class': TType.class_,
      'import': TType.import_,
      'export': TType.export_,
      'let': TType.let,
      'const': TType.const_,
      'auto': TType.auto,
      'reactive': TType.reactive,
      'true': TType.true_,
      'false': TType.false_,
      'null': TType.nullLiteral,
      'match': TType.match_,
      'switch': TType.switch_,
      'case': TType.case_,
      'default': TType.default_,
      'watch': TType.watch,
      'loop': TType.loop,
      'static': TType.static,
      'new': TType.new_,

      'this': TType.this_,
      'outer': TType.outer,
      'derives': TType.derives,
      'state': TType.state_,
      'try': TType.try_,
      'catch': TType.catch_,
      'throw': TType.throw_,
      'async': TType.asyncKw,
      'await': TType.awaitKw,
      'actions': TType.actions_,
      'requiresContext': TType.requiresContext_,
      'context': TType.context_,
    };

    final type = keywords[text] ?? TType.identifier;
    addToken(type, text, startLine, startColumn);
  }

  void _number(int startLine, int startColumn) {
    final start = index;
    while (_isDigit(current)) {
      advance();
    }

    if (current == '.' && _isDigit(_peek())) {
      advance(); // Consume dot
      while (_isDigit(current)) {
        advance();
      }
    }

    final value = source.substring(start, index);
    addToken(TType.number, value, startLine, startColumn);
  }

  int interpolationDepth = 0;
  List<String> quoteStack = [];

  void _string(String quote, int startLine, int startColumn, {bool isResume = false}) {
    final stringTokenLine = line;
    final stringTokenColumn = column;

    advance(); // Skip opening quote or }

    final start = index;
    bool hasInterpolation = false;

    while (!isAtEnd && current != quote) {
      if (current == r'$' && _peek() == '{') {
         hasInterpolation = true;
         break;
      }
      advance();
    }

    final value = source.substring(start, index);

    if (hasInterpolation) {
       if (!isResume) addToken(TType.lParen, '(', startLine, startColumn);
       addToken(TType.string, value, stringTokenLine, stringTokenColumn);
       addToken(TType.plus, '+', line, column);
       addToken(TType.lParen, '(', line, column);
       advance(); // skip $
       advance(); // skip {
       interpolationDepth++;
       quoteStack.add(quote);
       return;
    }

    advance(); // Skip closing quote
    addToken(TType.string, value, stringTokenLine, stringTokenColumn);
    if (isResume || interpolationDepth > 0 && isResume) {
       addToken(TType.rParen, ')', line, column);
    }
  }

  void _comment(int startLine, int startColumn) {
    int start = index - 1;
    while (!isAtEnd && current != '\n') {
      advance();
    }
    comments.add(Token(TType.comment, source.substring(start, index), startLine, startColumn));
  }

  bool _match(String expected) {
    if (isAtEnd) return false;
    if (source[index + 1] != expected) return false;
    index++;
    column++;
    return true;
  }

  String _peek() => (index + 1 >= source.length) ? '\u0000' : source[index + 1];

  bool _isWhitespace(String c) => c.trim().isEmpty;

  bool _isAlpha(String c) => RegExp(r'[a-zA-Z_]').hasMatch(c);
  bool _isDigit(String c) => RegExp(r'\d').hasMatch(c);
  bool _isAtEndOrInvalid(String c) => isAtEnd || !RegExp(r'[\w_]').hasMatch(c);
}
