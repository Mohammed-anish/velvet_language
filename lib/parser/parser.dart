import 'package:velvet_cmp/core/types.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/binery_expression_parse.dart';
import 'package:velvet_cmp/parser/core_parser.dart';

class Parser extends CoreParser with BineryOperations {
  Parser(super.tokenizer);
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
    var programe = Programe(body: body);
    // print(programe);
    return programe;
  }

  Node? parseStatement() {
    if (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
        matchNext(TType.identifier)) {
      return parseVariableDecl();
    } else if (match(TType.import_)) {
      return parseImport();
    } else if (match(TType.if_)) {
      return parseIfCondition();
    } else if (match(TType.while_)) {
      return parseWhileStatement();
    } else if (match(TType.for_)) {
      return parseForStatement();
    } else if (match(TType.fn)) {
      return parseFunction();
    } else if (match(TType.return_)) {
      return parseReturnStatement();
    } else if (match(TType.watch)) {
      return parseWatchStatement();
    } else if (match(TType.identifier) && matchNext(TType.assign)) {
      return parseAssignStatement();
    } else if (match(TType.loop)) {
      return parseLoopStatement();
    } else if (match(TType.try_)) {
      return parseTryStatement();
    } else if (match(TType.throw_)) {
      return parseThrowStatement();
    } else if (match(TType.class_)) {
      return classDeclaration();
    } else if (match(TType.new_)) {
      return classInstanciate();
    } else {
      if (!match(TType.newLine) && !match(TType.eof)) {
        return ExpressionStatement(expression());
      } else if (match(TType.newLine)) {
        eatNewLines();
        return null;
      } else if (match(TType.eof)) {
        return null;
      }
    }

    throw 'Unsupported: ${current().type}';
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

  List<Node> classBody() {
    Node bodyParse() {
      if (match(TType.static)) {
        advance();

        if (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
            matchNext(TType.identifier)) {
          return parseVariableDecl(isField: true, isStatic: true);
        } else if (match(TType.outer) && matchNext(TType.fn) ||
            match(TType.fn)) {
          return parseFunction(isStatic: true);
        }
      } else {
        if (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
            matchNext(TType.identifier)) {
          return parseVariableDecl(isField: true);
        } else if (match(TType.outer) && matchNext(TType.fn) ||
            match(TType.fn)) {
          return parseFunction();
        }
      }

      throw Exception(
          'Invalid class body: ${current().type}, ${current().line}');
    }

    List<Node> body = [];
    while (!match(TType.rBrace)) {
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

    return FunctionCall(callee: node, arguments: arguments);
  }

  List<Node> parseBlock() {
    List<Node> body = [];
    eat(TType.lBrace);

    while (!match(TType.rBrace)) {
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
    Node expr = primary();

    while (true) {
      if (match(TType.dot)) {
        advance();
        Token? property = eat(TType.identifier,
            exeption: "Expected property name after '.'.");
        expr = MemberAccess(object: expr, property: property!.value);
      } else if (match(TType.lBracket)) {
        advance();
        Node index = expression();
        eat(TType.rBracket, exeption: "Expect ']' after index.");
        expr = IndexAccessNode(target: expr, index: index);
      } else if (match(TType.lParen)) {
        expr = parseFunctionCall(expr);
      } else {
        break;
      }
    }

    if (expr is IdentifierNode) {
      return VariableNode(name: expr.name);
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
    Token token = current();

    if (match(TType.new_)) {
      return classInstanciate();
    } else if (match(TType.string)) {
      advance();
      return StringNode(token.value);
    } else if (match(TType.number)) {
      advance();
      return Number(value: num.parse(token.value));
    } else if (match(TType.false_) || match(TType.true_)) {
      advance();
      return BooleanNode(bool.parse(token.value));
    } else if (match(TType.identifier)) {
      advance();
      return IdentifierNode(token.value);
    } else if (match(TType.this_)) {
      advance();
      return ThisNode();
    } else if (match(TType.lParen)) {
      advance();
      Node expr = expression();
      eat(TType.rParen, exeption: "Expect ')' after expression.");
      return expr;
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
      return ArrayNode(elements: elements);
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
      return MapNode(entries: entries);
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
