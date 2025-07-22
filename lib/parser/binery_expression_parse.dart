import 'package:velvet_cmp/core/types.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/parser/core_parser.dart';

mixin BineryOperations on CoreParser {
  Node logicalOr() {
    Node expr = logicalAnd();
    while (anyMatch([TType.or_])) {
      final Token? op = advance();
      final Node right = logicalAnd();
      expr = BineryNode(left: expr, op: op!.value, right: right);
    }
    return expr;
  }

  Node logicalAnd() {
    Node expr = equality();
    while (anyMatch([TType.and_])) {
      final Token? op = advance();
      final Node right = equality();
      expr = BineryNode(left: expr, op: op!.value, right: right);
    }
    return expr;
  }

  Node equality() {
    Node expr = comparison();
    while (anyMatch([TType.doubleEqual, TType.notEqual])) {
      final Token? op = advance();
      final Node right = comparison();
      expr = BineryNode(left: expr, op: op!.value, right: right);
    }
    return expr;
  }

  Node comparison() {
    Node expr = term();
    while (anyMatch([
      TType.less,
      TType.lessEqual,
      TType.greater,
      TType.greaterEqual,
    ])) {
      final Token? op = advance();
      final Node right = term();
      expr = BineryNode(left: expr, op: op!.value, right: right);
    }
    return expr;
  }

  Node term() {
    Node expr = factor();
    while (anyMatch([TType.plus, TType.minus])) {
      final Token? op = advance();
      final Node right = factor();
      expr = BineryNode(left: expr, op: op!.value, right: right);
    }
    return expr;
  }

  Node factor() {
    Node expr = unary();
    while (anyMatch([TType.star, TType.slash])) {
      final Token? op = advance();
      final Node right = unary();
      expr = BineryNode(left: expr, op: op!.value, right: right);
    }
    return expr;
  }

  Node unary() {
    if (anyMatch([TType.minus, TType.bang])) {
      final Token op = advance()!;
      final right = unary();
      return UnaryExpr(op.value, right);
    }
    return primary();
  }

  Node primary();
}
