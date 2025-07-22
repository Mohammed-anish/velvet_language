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

  void tokenize() {
    while (!isAtEnd) {
      final start = index;
      final char = current;

      if (_isWhitespace(char)) {
        if (char == '\n') {
          addToken(TType.newLine, '\\n');
        }
        advance();
      } else if (_isAlpha(char)) {
        _identifierOrKeyword();
      } else if (_isDigit(char)) {
        _number();
      } else if (char == '"' || char == "'") {
        _string(char);
      } else {
        switch (char) {
          case '(':
            addToken(TType.lParen);
            break;
          case ')':
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
  }

  void _identifierOrKeyword() {
    final start = index;
    while (!_isAtEndOrInvalid(current)) advance();
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
      'loop': TType.loop
    };

    final type = keywords[text] ?? TType.identifier;
    addToken(type, text);
  }

  void _number() {
    final start = index;
    while (_isDigit(current)) advance();

    if (current == '.' && _isDigit(_peek())) {
      advance(); // Consume dot
      while (_isDigit(current)) advance();
    }

    final value = source.substring(start, index);
    addToken(TType.number, value);
  }

  void _string(String quote) {
    advance(); // Skip opening quote
    final start = index;
    while (!isAtEnd && current != quote) advance();
    final value = source.substring(start, index);
    advance(); // Skip closing quote
    addToken(TType.string, value);
  }

  void _comment() {
    while (!isAtEnd && current != '\n') advance();
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
