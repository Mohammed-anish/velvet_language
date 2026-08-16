import 'package:velvet_cmp/core/types.dart';

class Tokenizer {
  final String source;
  int index = 0;
  int line = 1;
  int column = 1;
  final List<Token> tokens = [];

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

  void addToken(TType type, [String? value]) {
    tokens.add(Token(type, value ?? current, line, column));
  }

  int parenDepth = 0;

  void tokenize() {
    while (!isAtEnd) {
      final start = index;
      final char = current;

      if (_isWhitespace(char)) {
        if (char == '\n' && parenDepth == 0) {
          addToken(TType.newLine, '\\n');
        }
        advance();
      } else if (_isAlpha(char)) {
        _identifierOrKeyword();
      } else if (_isDigit(char)) {
        _number();
      } else if (char == '"' || char == "'") {
        _string(char);
      } else if (char == '}' && interpolationDepth > 0) {
        addToken(TType.rParen, ')');
        addToken(TType.plus, '+');
        interpolationDepth--;
        _string(quoteStack.removeLast(), isResume: true);
      } else {
        switch (char) {
          case '(':
            parenDepth++;
            addToken(TType.lParen);
            break;
          case ')':
            if (parenDepth > 0) parenDepth--;
            addToken(TType.rParen);
            break;
          case '{':
            addToken(TType.lBrace);
            break;
          case '}':
            addToken(TType.rBrace);
            break;
          case '[':
            addToken(TType.lBracket);
            break;
          case ']':
            addToken(TType.rBracket);
            break;
          case '.':
            addToken(TType.dot);
            break;

          case ',':
            addToken(TType.comma);
            break;
          case ':':
            addToken(TType.colon);
            break;
          case ';':
            addToken(TType.semicolon);
            break;
          case '+':
            _match('=')
                ? addToken(TType.plusAssign, '+=')
                : addToken(TType.plus);
            break;
          case '-':
            if (_match('=')) {
              addToken(TType.minusAssign, '-=');
            } else if (_match('>')) {
              addToken(TType.arrow, '->');
            } else {
              addToken(TType.minus);
            }
            break;
          case '*':
            _match('=')
                ? addToken(TType.starAssign, '*=')
                : addToken(TType.star);
            break;
          case '/':
            if (_match('/')) {
              _comment();
            } else if (_match('=')) {
              addToken(TType.slashAssign, '/=');
            } else {
              addToken(TType.slash);
            }
            break;
          case '=':
            _match('=')
                ? addToken(TType.doubleEqual, '==')
                : addToken(TType.assign);
            break;
          case '!':
            _match('=') ? addToken(TType.notEqual, '!=') : addToken(TType.bang);
            break;
          case '>':
            _match('=')
                ? addToken(TType.greaterEqual, '>=')
                : addToken(TType.greater);
            break;
          case '<':
            _match('=')
                ? addToken(TType.lessEqual, '<=')
                : addToken(TType.less);
            break;
          case '&':
            if (_match('&')) addToken(TType.and_, '&&');
            break;
          case '|':
            if (_match('|')) addToken(TType.or_, '||');
            break;
          default:
            print("Unexpected char: $char");
        }
        advance();
      }
    }

    addToken(TType.eof, '');
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

  void _identifierOrKeyword() {
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
      'try': TType.try_,
      'catch': TType.catch_,
      'throw': TType.throw_,
      'async': TType.asyncKw,
      'await': TType.awaitKw,
    };

    final type = keywords[text] ?? TType.identifier;
    addToken(type, text);
  }

  void _number() {
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
    addToken(TType.number, value);
  }

  int interpolationDepth = 0;
  List<String> quoteStack = [];

  void _string(String quote, {bool isResume = false}) {
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
       if (!isResume) addToken(TType.lParen, '(');
       addToken(TType.string, value);
       addToken(TType.plus, '+');
       addToken(TType.lParen, '(');
       advance(); // skip $
       advance(); // skip {
       interpolationDepth++;
       quoteStack.add(quote);
       return;
    }

    advance(); // Skip closing quote
    addToken(TType.string, value);
    if (isResume || interpolationDepth > 0 && isResume) {
       addToken(TType.rParen, ')');
    }
  }

  void _comment() {
    while (!isAtEnd && current != '\n') {
      advance();
    }
    // addToken(TType.comment);
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
