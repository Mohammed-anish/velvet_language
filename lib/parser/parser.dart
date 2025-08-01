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
    print(programe);
    return programe;
  }

  Node? parseStatement() {
    if (anyMatch([TType.auto, TType.boolean, TType.identifier]) &&
        matchNext(TType.identifier)) {
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
        } else if (match(TType.fn)) {
          return parseFunction();
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
    print('c>>>${current().type}');

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

  Node parseFunction() {
    IdentifierNode? returnType;
    List<String> parameters = [];
    Token? outer = eat(TType.outer, isOptional: true);
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
    List<Node> body = [];
    if (outer == null) {
      body = parseBlock();
    }

    return FunctionDecl(
        name: name!.value,
        kind: 'public',
        returnType: returnType,
        body: body,
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
    if (instanceRequest()) {
      return classInstanciate();
    }
    Node expr = logicalOr(); //this is the current

    while (match(TType.dot)) {
      advance();
      Token? property =
          eat(TType.identifier, exeption: "Expected property name after '.'.");
      expr = MemberAccess(object: expr, property: property!.value);

      if (match(TType.assign)) {
        advance();
        Node value = expression();

        return AssignmentNode(target: expr, value: value);
      }
    }
    if (match(TType.lParen)) {
      //this is the match() gives next and checks next bcz primary already has advanced
      expr = parseFunctionCall(expr);
    }
    if (match(TType.new_)) {
      expr = classInstanciate();
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
    } else if (match(TType.this_)) {
      advance();
      return ThisNode();
    }
    if (match(TType.assign)) {
      advance();
      Node value = expression(); // Right-hand side of the assignment
      print('EXPR BRO $value');

      return AssignmentNode(target: value, value: value);
    }

    throw Exception(
        "Unexpected token in expression: ${token.type} : ${token.line}");
  }

  Node classInstanciate() {
    eat(TType.new_);
    Token? name = eat(TType.identifier);
    eat(TType.lParen);
    eat(TType.rParen);
    eat(TType.newLine, isOptional: true);

    return NewClassInstance(name: name?.value ?? '', args: []);
  }
}
