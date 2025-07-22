import 'dart:math';

import 'package:velvet_cmp/core/types.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/binery_expression_parse.dart';
import 'package:velvet_cmp/parser/core_parser.dart';

class Parser extends CoreParser with BineryOperations {
  Parser(super.tokenizer);
  @override
  Programe parse() {
    print(tokenizer.tokens);
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
    print(programe);
    return programe;
  }

  Node? parseStatement() {
    if (match(TType.auto)) {
      return parseVariableDecl();
    } else if (match(TType.if_)) {
      return parseIfCondition();
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

  Node parseVariableDecl() {
    print('c>>>${current().type}');
    Token? kind = eatAny([TType.auto, TType.boolean, TType.identifier]);
    print('c>>>${current().type}');

    Token? reactive = eat(TType.reactive, isOptional: true);
    print('c>>>${current().type}');

    Token? name = eat(TType.identifier, exeption: 'Variable name is required!');
    eat(TType.assign);
    Node expr = expression();
    eatNewLines();

    return VariableDeclarationNode(
        name: name!.value,
        kind: kind!.value,
        value: expr,
        isReactive: reactive != null);
  }

  Node parseAssignStatement() {
    Token? name = eat(TType.identifier);
    eat(TType.assign);
    Node expr = expression();

    return AssignmentNode(variableName: name!.value, value: expr);
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
    Token? number = eat(TType.number);
    eat(TType.comma, isOptional: true);
    Token? indexName = eat(TType.identifier, isOptional: true);

    eat(TType.rParen);
    List<Node> body = parseBlock();

    return LoopStatement(
        iterationTimes: int.parse(number!.value),
        body: body,
        indexName: indexName?.value);
  }

  Node parseFunction() {
    IdentifierNode? returnType;
    List<String> parameters = [];
    eat(TType.fn);
    print('examin ${current().type} ${getNext()?.type}');
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
    List<Node> body = parseBlock();

    return FunctionDecl(
        name: name!.value,
        kind: 'publoc',
        returnType: returnType,
        body: body,
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

  Node parseFunctionCall(Node node) {
    if (node is! IdentifierNode) {
      throw 'Identifier required';
    }

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

    return FunctionCall(name: node.name, arguments: arguments);
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
    Node expr = logicalOr(); //this is the current
    if (match(TType.lParen)) {
      //this is the match() gives next and checks next bcz primary already has advanced
      expr = parseFunctionCall(expr);
    }
    if (expr is IdentifierNode) {
      return VariableNode(name: expr.name);
    }
    return expr;
  }

  @override
  Node primary() {
    Token token = current();

    if (match(TType.string)) {
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
    }

    throw Exception(
        "Unexpected token in expression: ${token.type} : ${token.line}");
  }
}
