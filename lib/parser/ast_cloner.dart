import 'package:velvet_cmp/parser/ast_classes.dart';

class ASTCloner {
  final Map<String, Node> bindings;

  ASTCloner(this.bindings);

  List<Node> cloneList(List<Node> nodes) {
    return nodes.map((n) => clone(n)).toList();
  }

  Node clone(Node node) {
    if (node is IdentifierNode) {
      if (bindings.containsKey(node.name)) {
        return bindings[node.name]!;
      }
      return IdentifierNode(node.name);
    } else if (node is VariableNode) {
      if (bindings.containsKey(node.name)) {
        return bindings[node.name]!;
      }
      return VariableNode(name: node.name);
    } else if (node is BineryNode) {
      return BineryNode(
        left: clone(node.left),
        op: node.op,
        right: clone(node.right),
      );
    } else if (node is ExpressionStatement) {
      return ExpressionStatement(clone(node.value));
    } else if (node is FunctionDecl) {
      return FunctionDecl(
        name: node.name,
        kind: node.kind,
        body: cloneList(node.body),
        returnType: node.returnType != null ? clone(node.returnType!) : null,
        isOuter: node.isOuter,
        isStatic: node.isStatic,
        isAsync: node.isAsync,
        arguments: List.from(node.arguments),
      );
    } else if (node is FunctionCall) {
      return FunctionCall(
        callee: clone(node.callee),
        arguments: cloneList(node.arguments),
      );
    } else if (node is AwaitNode) {
      return AwaitNode(expression: clone(node.expression));
    } else if (node is Number) {
      return Number(value: node.value);
    } else if (node is StringNode) {
      return StringNode(node.value);
    } else if (node is UnaryExpr) {
      return UnaryExpr(node.operator, clone(node.right));
    } else if (node is PrintNode) {
      return PrintNode(node.value != null ? clone(node.value!) : null);
    } else if (node is ReturnNode) {
      return ReturnNode(value: clone(node.value));
    } else if (node is VariableDeclarationNode) {
      return VariableDeclarationNode(
        name: node.name,
        kind: node.kind,
        value: clone(node.value),
        isField: node.isField,
        isStatic: node.isStatic,
        isReactive: node.isReactive,
      );
    } else if (node is LoopStatement) {
      return LoopStatement(
        iterationTimes: clone(node.iterationTimes),
        body: cloneList(node.body),
        indexName: node.indexName,
      );
    } else if (node is AssignmentNode) {
      return AssignmentNode(
        target: clone(node.target),
        value: clone(node.value),
      );
    } else if (node is ThisNode) {
      return ThisNode();
    } else if (node is WatchStatement) {
      return WatchStatement(
        target: node.target,
        body: cloneList(node.body),
      );
    } else if (node is IfNode) {
      return IfNode(
        condition: clone(node.condition),
        ifBlock: cloneList(node.ifBlock),
        elseNode: node.elseNode != null ? cloneList(node.elseNode!) : null,
      );
    } else if (node is BooleanNode) {
      return BooleanNode(node.value);
    } else if (node is MemberAccess) {
      return MemberAccess(
        object: clone(node.object),
        property: node.property,
      );
    } else if (node is ClassDeclration) {
      return ClassDeclration(
        name: node.name,
        body: cloneList(node.body),
        superClasses: List.from(node.superClasses),
      );
    } else if (node is StateDeclration) {
      return StateDeclration(
        name: node.name,
        values: List.from(node.values),
      );
    } else if (node is NewClassInstance) {
      return NewClassInstance(
        name: node.name,
        args: cloneList(node.args),
      );
    } else if (node is WhileNode) {
      return WhileNode(
        condition: clone(node.condition),
        body: cloneList(node.body),
      );
    } else if (node is ForNode) {
      return ForNode(
        init: node.init != null ? clone(node.init!) : null,
        condition: node.condition != null ? clone(node.condition!) : null,
        update: node.update != null ? clone(node.update!) : null,
        body: cloneList(node.body),
      );
    } else if (node is ArrayNode) {
      return ArrayNode(elements: cloneList(node.elements));
    } else if (node is IndexAccessNode) {
      return IndexAccessNode(
        target: clone(node.target),
        index: clone(node.index),
      );
    } else if (node is ImportNode) {
      return ImportNode(path: node.path);
    } else if (node is MapNode) {
      return MapNode(
        entries: node.entries.map((k, v) => MapEntry(clone(k), clone(v))),
      );
    } else if (node is TryCatchNode) {
      return TryCatchNode(
        tryBlock: cloneList(node.tryBlock),
        catchVar: node.catchVar,
        catchBlock: cloneList(node.catchBlock),
      );
    } else if (node is ThrowNode) {
      return ThrowNode(expression: clone(node.expression));
    } else if (node is BlockNode) {
      return BlockNode(statements: cloneList(node.statements));
    }

    // Default: return the same node if we don't know how to clone it
    return node;
  }
}
