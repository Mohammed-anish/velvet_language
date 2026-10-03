import 'package:velvet_cmp/core/types.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/binery_expression_parse.dart';
import 'package:velvet_cmp/parser/ast_cloner.dart';
import 'package:velvet_cmp/parser/core_parser.dart';
import 'package:velvet_cmp/parser/action_registry.dart';

class Parser extends CoreParser with BineryOperations {
  final String? sourceName;
  Parser(super.tokenizer, {this.sourceName});
  @override
  Programe parse() {
    final List<Node> body = [];
    while (!isEof()) {
      while (match(TType.newLine)) {
        advance();
      }
      Node? statement = parseStatement();
      if (statement != null) {
        body.add(statement);
      }
    }
    if (errors.isNotEmpty) {
      final err = errors.first;
      final file = sourceName ?? '<script>';
      final sourceLines = tokenizer.source.split('\n');

      var buffer = StringBuffer();
      buffer.writeln('Syntax Error in $file:${err.line}:${err.column}');
      buffer.writeln('');
      // Show the offending source line with line number
      if (err.line > 0 && err.line <= sourceLines.length) {
        final lineContent = sourceLines[err.line - 1];
        final lineNum = '${err.line}'.padLeft(4);
        buffer.writeln('$lineNum | ${lineContent.trimRight()}');
        // Caret pointer
        final caretPad =
            ' ' * (lineNum.length + 3 + (err.column > 0 ? err.column - 1 : 0));
        buffer.writeln('$caretPad^');
      }
      buffer.write(err.message);
      throw Exception(buffer.toString());
    }
    var programe = Programe(body: body);
    // print(programe);
    return programe;
  }

  Node? parseStatement() {
    int startLine = current().line;
    int startColumn = current().column;
    Node? stmt;

    try {
      if (match(TType.actions_)) {
        parseActionsBlock();
        return null;
      } else if (match(TType.requiresContext_)) {
        stmt = parseRequiresContext();
      } else if (match(TType.identifier) &&
          ActionRegistry().get(current().value) != null &&
          peek().type != TType.assign) {
        stmt = parseActionInvocation(ActionRegistry().get(current().value)!);
      } else if (match(TType.context_) ||
          (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
              matchNext(TType.identifier))) {
        stmt = parseVariableDecl();
      } else if (match(TType.import_)) {
        stmt = parseImport();
      } else if (match(TType.if_)) {
        stmt = parseIfCondition();
      } else if (match(TType.while_)) {
        stmt = parseWhileStatement();
      } else if (match(TType.for_)) {
        stmt = parseForStatement();
      } else if (match(TType.fn) || match(TType.asyncKw)) {
        stmt = parseFunction();
      } else if (match(TType.return_)) {
        stmt = parseReturnStatement();
      } else if (match(TType.watch)) {
        stmt = parseWatchStatement();
      } else if (match(TType.identifier) && matchNext(TType.assign)) {
        stmt = parseAssignStatement();
      } else if (match(TType.loop)) {
        stmt = parseLoopStatement();
      } else if (match(TType.try_)) {
        stmt = parseTryStatement();
      } else if (match(TType.throw_)) {
        stmt = parseThrowStatement();
      } else if (match(TType.class_)) {
        stmt = classDeclaration();
      } else if (match(TType.state_)) {
        stmt = parseStateDeclration();
      } else if (match(TType.new_)) {
        stmt = classInstanciate();
      } else {
        if (!match(TType.newLine) && !match(TType.eof)) {
          stmt = ExpressionStatement(expression());
        } else if (match(TType.newLine)) {
          eatNewLines();
          return null;
        } else if (match(TType.eof)) {
          return null;
        } else {
          throw Exception('Unsupported token: ${current().type}');
        }
      }
    } catch (e) {
      errors.add(ParserError(e.toString(), current().line, current().column));
      _synchronize();
      return null;
    }

    if (stmt != null) {
      if (i > 0) {
        Token prev = previous();
        if (prev.line == current().line &&
            !match(TType.newLine) &&
            !match(TType.eof) &&
            !match(TType.rBrace)) {
          throw Exception(
              'Syntax Error: Unexpected token "${current().value}" after statement on line ${current().line}. Did you forget a newline?');
        }
      }
      return recordPos(stmt, startLine, startColumn);
    }
    return null;
  }

  void _synchronize() {
    advance();
    while (!isEof()) {
      if (previous().type == TType.newLine ||
          previous().type == TType.semicolon) return;

      switch (current().type) {
        case TType.class_:
        case TType.fn:
        case TType.auto:
        case TType.for_:
        case TType.if_:
        case TType.while_:
        case TType.return_:
        case TType.import_:
          return;
        default:
          advance();
      }
    }
  }

  void parseActionsBlock() {
    eat(TType.actions_);
    eat(TType.lBrace);
    while (!match(TType.rBrace) && !isEof()) {
      eatNewLines();
      if (match(TType.rBrace)) break;

      Token? nameToken = eat(TType.identifier);
      if (nameToken == null) throw 'Expected action name at ${current().line}';
      String actionName = nameToken.value;

      eat(TType.lParen);
      List<ActionParameter> parameters = [];
      if (!match(TType.rParen)) {
        do {
          Token? paramNameToken = eat(TType.identifier);
          eat(TType.colon);
          Token? paramTypeToken = eat(TType.identifier);

          if (paramNameToken != null && paramTypeToken != null) {
            parameters.add(
                ActionParameter(paramNameToken.value, paramTypeToken.value));
          }

          if (match(TType.comma)) {
            eat(TType.comma);
          } else {
            break;
          }
        } while (true);
      }
      eat(TType.rParen);

      List<Node> body = parseBlock();

      ActionRegistry().register(ActionDefinition(actionName, parameters, body));
      eatNewLines();
    }
    eat(TType.rBrace);
  }

  Node parseRequiresContext() {
    eat(TType.requiresContext_);
    List<String> variables = [];
    do {
      Token? varName = eat(TType.identifier,
          exeption: 'Expected variable name for requiresContext');
      if (varName != null) {
        variables.add(varName.value);
      }
      if (match(TType.comma)) {
        eat(TType.comma);
      } else {
        break;
      }
    } while (true);
    eatNewLines();
    return RequiresContextNode(variables: variables);
  }

  Node parseActionInvocation(ActionDefinition def) {
    eat(TType.identifier); // consume action name
    Map<String, Node> bindings = {};

    for (var param in def.parameters) {
      if (param.syntaxType == 'string') {
        Token? t = eat(TType.string);
        bindings[param.name] = StringNode(t!.value);
      } else if (param.syntaxType == 'number') {
        Token? t = eat(TType.number);
        bindings[param.name] = Number(value: num.parse(t!.value));
      } else if (param.syntaxType == 'boolean') {
        Token? t = eatAny([TType.true_, TType.false_]);
        bindings[param.name] = BooleanNode(bool.parse(t!.value));
      } else if (param.syntaxType == 'identifier') {
        Token? t = eat(TType.identifier);
        bindings[param.name] = IdentifierNode(t!.value);
      } else if (param.syntaxType == 'keyword') {
        final token = current();
        if (!_isActionKeyword(token.type)) {
          throw 'Expected keyword for action parameter "${param.name}" at '
              '${token.line}:${token.column}';
        }
        advance();
        bindings[param.name] = KeywordNode(token.value);
      } else if (param.syntaxType == 'expression') {
        bindings[param.name] = expression();
      } else if (param.syntaxType == 'statement') {
        final statement = parseStatement();
        if (statement == null) {
          throw 'Expected statement for action parameter "${param.name}" at '
              '${current().line}:${current().column}';
        }
        bindings[param.name] = statement;
      } else if (param.syntaxType == 'block') {
        bindings[param.name] = CallableBlockNode(statements: parseBlock());
      } else if (param.syntaxType == 'type') {
        final token = eat(TType.identifier,
            exeption:
                'Expected type name for action parameter "${param.name}"');
        bindings[param.name] = TypeNode(token!.value);
      } else if (param.syntaxType == 'parameters') {
        bindings[param.name] = _parseActionParameters();
      } else {
        throw 'Unsupported action parameter type: ${param.syntaxType}';
      }
    }

    var cloner = ASTCloner(bindings);
    return BlockNode(statements: cloner.cloneList(def.body));
  }

  ParametersNode _parseActionParameters() {
    eat(TType.lParen,
        exeption: 'Expected "(" to start an action parameters capture');
    final names = <String>[];
    if (!match(TType.rParen)) {
      do {
        final parameter = eat(TType.identifier,
            exeption: 'Action parameters must be identifiers');
        names.add(parameter!.value);
        if (match(TType.comma)) {
          eat(TType.comma);
        } else {
          break;
        }
      } while (true);
    }
    eat(TType.rParen,
        exeption: 'Expected ")" to finish an action parameters capture');
    return ParametersNode(names);
  }

  bool _isActionKeyword(TType type) {
    return {
      TType.fn,
      TType.if_,
      TType.else_,
      TType.while_,
      TType.for_,
      TType.return_,
      TType.break_,
      TType.continue_,
      TType.class_,
      TType.import_,
      TType.export_,
      TType.let,
      TType.const_,
      TType.auto,
      TType.match_,
      TType.switch_,
      TType.case_,
      TType.default_,
      TType.try_,
      TType.catch_,
      TType.throw_,
      TType.asyncKw,
      TType.awaitKw,
      TType.watch,
      TType.loop,
      TType.static,
      TType.new_,
      TType.outer,
      TType.derives,
      TType.state_,
    }.contains(type);
  }

  Node classDeclaration() {
    eat(TType.class_);
    Token? name = eat(TType.identifier);
    bool isDerived = eat(TType.derives, isOptional: true) != null;
    List<String> superClasses = [];
    do {
      final Token? superClass = eat(TType.identifier, isOptional: !isDerived);
      if (superClass != null) superClasses.add(superClass.value);

      if (match(TType.comma)) {
        eat(TType.comma);
      } else {
        break;
      }
    } while (true);

    eat(TType.lBrace);
    List<Node> body = classBody();
    eat(TType.rBrace);

    return ClassDeclration(
        body: body, name: name!.value, superClasses: superClasses);
  }

  Node parseStateDeclration() {
    eat(TType.state_);
    Token? name = eat(TType.identifier);
    eat(TType.lBrace);

    List<String> values = [];
    while (!match(TType.rBrace) && !isEof()) {
      eatNewLines();
      if (match(TType.rBrace)) break;
      Token? valToken = eat(TType.identifier);
      if (valToken != null) {
        values.add(valToken.value);
      }
      eatNewLines();
    }

    eat(TType.rBrace);
    return StateDeclration(name: name!.value, values: values);
  }

  List<Node> classBody() {
    Node bodyParse() {
      if (match(TType.static)) {
        advance();

        if (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
            matchNext(TType.identifier)) {
          return parseVariableDecl(isField: true, isStatic: true);
        } else if ((match(TType.outer) &&
                (matchNext(TType.fn) || matchNext(TType.asyncKw))) ||
            match(TType.fn) ||
            match(TType.asyncKw)) {
          return parseFunction(isStatic: true);
        }
      } else {
        if (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
            matchNext(TType.identifier)) {
          return parseVariableDecl(isField: true);
        } else if ((match(TType.outer) &&
                (matchNext(TType.fn) || matchNext(TType.asyncKw))) ||
            match(TType.fn) ||
            match(TType.asyncKw)) {
          return parseFunction();
        }
      }

      throw Exception(
          'Invalid class body: ${current().type}, ${current().line}');
    }

    List<Node> body = [];
    while (!match(TType.rBrace) && !isEof()) {
      eatNewLines();
      if (match(TType.rBrace)) break; // in case newline was right before }

      body.add(bodyParse());
    }

    return body;
  }

  Node parseVariableDecl({bool isField = false, bool isStatic = false}) {
    Token? staticKeyword = eat(
      TType.static,
      isOptional: true,
    );
    Token? contextKeyword = eat(
      TType.context_,
      isOptional: true,
    );
    Token? kind = eatAny([TType.auto, TType.boolean, TType.identifier]);

    Token? reactive = eat(TType.reactive, isOptional: true);
    // print('c>>>${current().type}');

    Token? name = eat(TType.identifier,
        exeption: 'Variable name is required! at ${current().line}');
    eat(TType.assign);
    Node expr = expression();
    eatNewLines();

    return VariableDeclarationNode(
        name: name!.value,
        kind: kind!.value,
        value: expr,
        isStatic: isStatic,
        isField: isField,
        isContext: contextKeyword != null,
        isReactive: reactive != null);
  }

  Node parseTryStatement() {
    eat(TType.try_);
    List<Node> tryBlock = parseBlock();

    eat(TType.catch_);
    String? catchVar;
    if (match(TType.lParen)) {
      eat(TType.lParen);
      catchVar = eat(TType.identifier)?.value;
      eat(TType.rParen);
    }
    List<Node> catchBlock = parseBlock();

    return TryCatchNode(
        tryBlock: tryBlock, catchVar: catchVar, catchBlock: catchBlock);
  }

  Node parseThrowStatement() {
    eat(TType.throw_);
    Node expr = expression();
    return ThrowNode(expression: expr);
  }

  Node parseAssignStatement() {
    Token? name = eat(TType.identifier);
    eat(TType.assign);
    Node expr = expression();

    return AssignmentNode(target: IdentifierNode(name!.value), value: expr);
  }

  Node parseWatchStatement() {
    eat(TType.watch);
    Token? target = eat(TType.identifier);
    List<Node> body = parseBlock();
    return WatchStatement(target: target!.value, body: body);
  }

  Node parseLoopStatement() {
    eat(TType.loop);
    eat(TType.lParen);
    Node number = expression();
    eat(TType.comma, isOptional: true);
    Token? indexName = eat(TType.identifier, isOptional: true);
    eat(TType.rParen);
    List<Node> body = parseBlock();
    return LoopStatement(
        iterationTimes: number, body: body, indexName: indexName?.value);
  }

  Node parseFunction({bool isStatic = false}) {
    IdentifierNode? returnType;
    List<String> parameters = [];
    Token? outer = eat(TType.outer, isOptional: true);
    Token? asyncKw = eat(TType.asyncKw, isOptional: true);
    eat(TType.fn);
    // print('examin ${current().type} ${getNext()?.type}');
    if ((current().type == TType.identifier || current().type == TType.auto) &&
        getNext()?.type == TType.identifier) {
      Token? type = current().type == TType.identifier
          ? eat(TType.identifier)
          : eat(TType.auto);
      if (type != null) returnType = IdentifierNode(type.value);
    }
    Token? name = eat(TType.identifier);
    eat(TType.lParen);
    if (!match(TType.rParen)) {
      do {
        Token? parameter = eat(TType.identifier,
            exeption:
                'Argument requires identifier but got: ${current().value}');
        // advance();
        parameters.add(parameter!.value);

        if (match(TType.comma)) {
          eat(TType.comma);
        } else {
          break;
        }
      } while (true);
    }
    eat(TType.rParen);
    List<Node> body = [];
    if (outer == null) {
      body = parseBlock();
    }

    return FunctionDecl(
        name: name!.value,
        kind: 'public',
        returnType: returnType,
        body: body,
        isStatic: isStatic,
        isOuter: outer != null,
        isAsync: asyncKw != null,
        arguments: parameters);
  }

  Node parseReturnStatement() {
    eat(TType.return_);
    var expr = expression();

    return ReturnNode(value: expr);
  }

  Node parseIfCondition() {
    eat(TType.if_);
    eat(TType.lParen, exeption: '( is required');
    late Node condition;
    if (!match(TType.rParen)) {
      condition = expression(); // only parse expression if it's not empty
    } else {
      throw 'Condition is required';
    }
    // print(current().type);
    eat(TType.rParen, exeption: ') is required');

    List<Node> body = parseBlock();
    List<Node>? elseNode;
    // print('>> ${current().value}');
    if (match(TType.else_)) {
      advance();
      elseNode = parseBlock();
    }
    return IfNode(condition: condition, ifBlock: body, elseNode: elseNode);
  }

  Node parseWhileStatement() {
    eat(TType.while_);
    eat(TType.lParen, exeption: '( is required');
    Node condition = expression();
    eat(TType.rParen, exeption: ') is required');
    List<Node> body = parseBlock();
    return WhileNode(condition: condition, body: body);
  }

  Node parseForStatement() {
    eat(TType.for_);
    eat(TType.lParen);

    Node? init;
    if (!match(TType.semicolon)) {
      // It might be a variable declaration or an assignment
      if (current().type == TType.auto ||
          current().type == TType.boolean ||
          (current().type == TType.identifier &&
              peek().type == TType.identifier)) {
        init = parseVariableDecl();
      } else {
        init = parseAssignStatement(); // Assuming assignments can be parsed
      }
      eat(TType.semicolon);
    } else {
      eat(TType.semicolon);
    }

    Node? condition;
    if (!match(TType.semicolon)) {
      condition = expression();
      eat(TType.semicolon);
    } else {
      eat(TType.semicolon);
    }

    Node? update;
    if (!match(TType.rParen)) {
      if (current().type == TType.identifier && peek().type == TType.assign) {
        update = parseAssignStatement();
      } else {
        update = expression();
      }
      eat(TType.rParen);
    } else {
      eat(TType.rParen);
    }

    List<Node> body = parseBlock();
    return ForNode(
        init: init, condition: condition, update: update, body: body);
  }

  Node parseImport() {
    eat(TType.import_);
    Token? pathToken =
        eat(TType.string, exeption: 'Import path must be a string');
    eatNewLines();
    return ImportNode(path: pathToken!.value);
  }

  Node parseFunctionCall(Node node) {
    int startLine = current().line;
    int startColumn = current().column;
    eat(TType.lParen);
    List<Node> arguments = [];
    if (!match(TType.rParen)) {
      do {
        Node arg = expression();
        arguments.add(arg);
        if (match(TType.comma)) {
          eat(TType.comma);
        } else {
          break;
        }
      } while (true);
    }
    eat(TType.rParen);
    eatNewLines();

    return FunctionCall(callee: node, arguments: arguments)
      ..line = startLine
      ..column = startColumn;
  }

  List<Node> parseBlock() {
    List<Node> body = [];
    eat(TType.lBrace);

    while (!match(TType.rBrace) && !isEof()) {
      Node? statement = parseStatement();
      if (statement != null) body.add(statement);
    }
    eat(TType.rBrace);
    return body;
  }

  Node expression() {
    Node expr = logicalOr();
    if (match(TType.assign)) {
      advance();
      Node value = expression();
      return AssignmentNode(target: expr, value: value);
    }
    return expr;
  }

  @override
  Node call() {
    int startLine = current().line;
    int startColumn = current().column;
    Node expr = primary();

    while (true) {
      if (match(TType.dot)) {
        advance();
        Token? property = eat(TType.identifier,
            exeption: "Expected property name after '.'.");
        expr = recordPos(MemberAccess(object: expr, property: property!.value),
            startLine, startColumn);
      } else if (match(TType.lBracket)) {
        advance();
        Node index = expression();
        eat(TType.rBracket, exeption: "Expect ']' after index.");
        expr = recordPos(IndexAccessNode(target: expr, index: index), startLine,
            startColumn);
      } else if (match(TType.lParen)) {
        expr = recordPos(parseFunctionCall(expr), startLine, startColumn);
      } else {
        break;
      }
    }

    if (expr is IdentifierNode) {
      return recordPos(VariableNode(name: expr.name), startLine, startColumn);
    }

    return expr;
  }

  bool instanceRequest() {
    if (match(TType.new_)) {
      return true;
    }
    return false;
  }

  Token peek() {
    if (i + 1 < tokens.length) {
      return tokens[i + 1];
    }
    return tokens[i]; // or EOF
  }

  @override
  Node primary() {
    int startLine = current().line;
    int startColumn = current().column;
    Token token = current();
    Node? node;

    if (match(TType.new_)) {
      node = classInstanciate();
    } else if (match(TType.string)) {
      advance();
      node = StringNode(token.value);
    } else if (match(TType.number)) {
      advance();
      node = Number(value: num.parse(token.value));
    } else if (match(TType.false_) || match(TType.true_)) {
      advance();
      node = BooleanNode(bool.parse(token.value));
    } else if (match(TType.nullLiteral)) {
      advance();
      node = NullNode();
    } else if (match(TType.identifier)) {
      advance();
      node = IdentifierNode(token.value);
    } else if (match(TType.this_)) {
      advance();
      node = ThisNode();
    } else if (match(TType.lParen)) {
      advance();
      Node expr = expression();
      eat(TType.rParen, exeption: "Expect ')' after expression.");
      node = expr;
    } else if (match(TType.lBracket)) {
      advance();
      List<Node> elements = [];
      if (!match(TType.rBracket)) {
        do {
          elements.add(expression());
          if (match(TType.comma)) {
            eat(TType.comma);
          } else {
            break;
          }
        } while (true);
      }
      eat(TType.rBracket, exeption: "Expect ']' after array elements.");
      node = ArrayNode(elements: elements);
    } else if (match(TType.lBrace)) {
      advance();
      Map<Node, Node> entries = {};
      if (!match(TType.rBrace)) {
        do {
          Node key = expression();
          eat(TType.colon, exeption: "Expect ':' after map key.");
          Node value = expression();
          entries[key] = value;
          if (match(TType.comma)) {
            eat(TType.comma);
          } else {
            break;
          }
        } while (true);
      }
      eat(TType.rBrace, exeption: "Expect '}' after map entries.");
      node = MapNode(entries: entries);
    }

    if (node != null) {
      return recordPos(node, startLine, startColumn);
    }

    throw Exception(
        "Unexpected token in expression: ${token.type} : ${token.line}");
  }

  Node classInstanciate() {
    eat(TType.new_);
    Token? name = eat(TType.identifier);
    eat(TType.lParen);

    List<Node> args = [];
    if (!match(TType.rParen)) {
      do {
        args.add(expression());
        if (match(TType.comma)) {
          eat(TType.comma);
        } else {
          break;
        }
      } while (true);
    }

    eat(TType.rParen);
    eat(TType.newLine, isOptional: true);

    return NewClassInstance(name: name?.value ?? '', args: args);
  }
}
