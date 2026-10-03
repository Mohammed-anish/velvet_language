abstract class Node {
  int line = -1;
  int column = -1;
  int endLine = -1;
  int endColumn = -1;
}

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
  final bool isOuter;
  final bool isStatic;
  FunctionDecl(
      {required this.name,
      this.returnType,
      required this.kind,
      required this.body,
      required this.arguments,
      required this.isOuter,
      this.isStatic = false,
      this.isAsync = false});
  final List<String> arguments;
  final bool isAsync;

  @override
  String toString() {
    return 'FunctionDecl(name: $name, kind: $kind, body: $body, returnType: $returnType, isOuter: $isOuter, isStatic: $isStatic, isAsync: $isAsync, arguments: $arguments)';
  }
}

class FunctionCall extends Node {
  final Node callee;
  final List<Node> arguments;
  FunctionCall({
    required this.callee,
    required this.arguments,
  });

  @override
  String toString() => 'FunctionCall(name: $callee, arguments: $arguments)';
}

class AwaitNode extends Node {
  final Node expression;
  AwaitNode({required this.expression});

  @override
  String toString() => 'AwaitNode(expression: $expression)';
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
  final bool isField;
  final bool isStatic;
  final bool isContext;

  VariableDeclarationNode(
      {required this.name,
      required this.kind,
      required this.value,
      required this.isField,
      required this.isStatic,
      this.isContext = false,
      this.isReactive = false});

  @override
  String toString() {
    return 'VariableDeclarationNode(name: $name, kind: $kind, value: $value, isReactive: $isReactive, isField: $isField, isStatic: $isStatic, isContext: $isContext)';
  }
}

class LoopStatement extends Node {
  final Node iterationTimes;
  final String? indexName;
  final List<Node> body;
  LoopStatement({
    required this.iterationTimes,
    required this.body,
    this.indexName,
  });
}

class AssignmentNode extends Node {
  final Node target;
  final Node value;

  AssignmentNode({
    required this.target,
    required this.value,
  });

  @override
  String toString() => 'AssignmentNode(target: $target, value: $value)';
}

class ThisNode extends Node {}

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

/// A literal language word captured by an Action. Unlike [VariableNode], this
/// represents the word itself and never performs a scope lookup.
class KeywordNode extends Node {
  final String value;
  KeywordNode(this.value);

  @override
  String toString() => 'KeywordNode(value: $value)';
}

/// A type name captured by an Action declaration.
class TypeNode extends Node {
  final String name;
  TypeNode(this.name);

  @override
  String toString() => 'TypeNode(name: $name)';
}

/// A function-style list of parameter names captured by an Action.
class ParametersNode extends Node {
  final List<String> names;
  ParametersNode(this.names);

  @override
  String toString() => 'ParametersNode(names: $names)';
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

class MemberAccess extends Node {
  final Node object;
  final String property;
  MemberAccess({
    required this.object,
    required this.property,
  });

  @override
  String toString() => 'MemberAccess(object: $object, property: $property)';
}

class ClassDeclration extends Node {
  final String name;
  final List<Node> body;
  final List<String> superClasses;

  ClassDeclration(
      {required this.name, required this.body, required this.superClasses});

  @override
  String toString() =>
      'ClassDeclration(name: $name,superClasses:$superClasses, body: $body )';
}

class StateDeclration extends Node {
  final String name;
  final List<String> values;

  StateDeclration({required this.name, required this.values});

  @override
  String toString() => 'StateDeclration(name: $name, values: $values)';
}

class NewClassInstance extends Node {
  final String name;
  final List<Node> args;
  NewClassInstance({
    required this.name,
    required this.args,
  });

  @override
  String toString() => 'NewClassInstance(name: $name, args: $args)';
}

class WhileNode extends Node {
  final Node condition;
  final List<Node> body;

  WhileNode({required this.condition, required this.body});

  @override
  String toString() => 'WhileNode(condition: $condition, body: $body)';
}

class ForNode extends Node {
  final Node? init;
  final Node? condition;
  final Node? update;
  final List<Node> body;

  ForNode({this.init, this.condition, this.update, required this.body});
}

class ArrayNode extends Node {
  final List<Node> elements;

  ArrayNode({required this.elements});

  @override
  String toString() => 'ArrayNode(elements: $elements)';
}

class IndexAccessNode extends Node {
  final Node target;
  final Node index;

  IndexAccessNode({required this.target, required this.index});

  @override
  String toString() => 'IndexAccessNode(target: $target, index: $index)';
}

class ImportNode extends Node {
  final String path;

  ImportNode({required this.path});

  @override
  String toString() => 'ImportNode(path: $path)';
}

class MapNode extends Node {
  final Map<Node, Node> entries;

  MapNode({required this.entries});

  @override
  String toString() => 'MapNode(entries: $entries)';
}

class TryCatchNode extends Node {
  final List<Node> tryBlock;
  final String? catchVar;
  final List<Node> catchBlock;

  TryCatchNode({
    required this.tryBlock,
    this.catchVar,
    required this.catchBlock,
  });

  @override
  String toString() => 'TryCatchNode(catchVar: $catchVar)';
}

class ThrowNode extends Node {
  final Node expression;

  ThrowNode({required this.expression});

  @override
  String toString() => 'ThrowNode(expression: $expression)';
}

class BlockNode extends Node {
  final List<Node> statements;

  BlockNode({required this.statements});

  @override
  String toString() => 'BlockNode(statements: $statements)';
}

class CallableBlockNode extends Node {
  final List<Node> statements;
  CallableBlockNode({required this.statements});

  @override
  String toString() => 'CallableBlockNode(statements: $statements)';
}

class RequiresContextNode extends Node {
  final List<String> variables;
  RequiresContextNode({required this.variables});

  @override
  String toString() => 'RequiresContextNode(variables: $variables)';
}

class NullNode extends Node {
  @override
  String toString() => 'NullNode()';
}
