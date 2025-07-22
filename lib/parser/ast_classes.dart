import 'package:velvet_cmp/core/types.dart';

abstract class Node {}

class BineryNode extends Node {
  final Node left;
  final String op;
  final Node right;
  BineryNode({required this.left, required this.op, required this.right});

  @override
  String toString() => 'BineryNode(left: $left, op: $op, right: $right)';
}

class ExpressionStatement extends Node {
  final Node value;
  ExpressionStatement(this.value);

  @override
  String toString() => 'ExpressionStatement(value: $value)';
}

class FunctionDecl extends Node {
  final String name;
  final String kind;
  final List<Node> body;
  final Node? returnType;
  FunctionDecl(
      {required this.name,
      this.returnType,
      required this.kind,
      required this.body,
      required this.arguments});
  final List<String> arguments;

  @override
  String toString() => 'FunctionDecl(name: $name, kind: $kind, body: $body)';
}

class FunctionCall extends Node {
  final String name;
  final List<Node> arguments;
  FunctionCall({
    required this.name,
    required this.arguments,
  });

  @override
  String toString() => 'FunctionCall(name: $name, arguments: $arguments)';
}

class Programe extends Node {
  final List<Node> body;
  Programe({required this.body});

  @override
  String toString() => 'Programe(body: $body)';
}

class Number extends Node {
  final num value;
  Number({required this.value});

  @override
  String toString() => 'Number(value: $value)';
}

class StringNode extends Node {
  final String value;
  StringNode(this.value);

  @override
  String toString() => 'StringNode(value: $value)';
}

class UnaryExpr extends Node {
  final String operator;
  final Node right;

  UnaryExpr(this.operator, this.right);
}

class VariableNode extends Node {
  final String name;
  VariableNode({required this.name});

  @override
  String toString() => 'VariableNode(name: $name)';
}

class PrintNode extends Node {
  final Node? value;
  PrintNode(this.value);

  @override
  String toString() => 'PrintNode(value: $value)';
}

class ReturnNode extends Node {
  final Node value;
  ReturnNode({required this.value});

  @override
  String toString() => 'ReturnNode(value: $value)';
}

class VariableDeclarationNode extends Node {
  final String name;
  final String kind;
  final Node value;
  final bool isReactive;

  VariableDeclarationNode(
      {required this.name,
      required this.kind,
      required this.value,
      this.isReactive = false});

  @override
  String toString() {
    return 'VariableDeclarationNode(name: $name, kind: $kind, value: $value, isReactive: $isReactive)';
  }
}

class LoopStatement extends Node {
  final int iterationTimes;
  final String? indexName;
  final List<Node> body;
  LoopStatement({
    required this.iterationTimes,
    required this.body,
    this.indexName,
  });
}

class AssignmentNode extends Node {
  final String variableName;
  final Node value;

  AssignmentNode({
    required this.variableName,
    required this.value,
  });
}

class WatchStatement extends Node {
  final String target;
  final List<Node> body;
  WatchStatement({
    required this.target,
    required this.body,
  });

  @override
  String toString() => 'WatchStatement(target: $target, body: $body)';
}

class IdentifierNode extends Node {
  final String name;
  IdentifierNode(this.name);

  @override
  String toString() => 'IdentifierNode(name: $name)';
}

class IfNode extends Node {
  final Node condition;
  final List<Node> ifBlock;
  final List<Node>? elseNode;
  IfNode({required this.condition, required this.ifBlock, this.elseNode});

  @override
  String toString() =>
      'IfNode(condition: $condition, ifBlock: $ifBlock, elseNode: $elseNode)';
}

class BooleanNode extends Node {
  final bool value;
  BooleanNode(this.value);

  @override
  String toString() => 'BooleanNode(value: $value)';
}
