import 'package:velvet_cmp/parser/ast_classes.dart';

abstract class VmlNode {
  VmlElement? parent;
}

class VmlText extends VmlNode {
  final String text;

  VmlText(this.text);

  @override
  String toString() => text;
}

class VmlElement extends VmlNode {
  final String tagName;
  final Map<String, dynamic> attributes;
  final List<VmlNode> children;

  VmlElement(this.tagName, {this.attributes = const {}, List<VmlNode>? children})
      : children = children ?? [] {
    for (var child in this.children) {
      child.parent = this;
    }
  }

  VmlElement? querySelector(String tag) {
    if (tagName == tag) return this;
    for (var child in children) {
      if (child is VmlElement) {
        var result = child.querySelector(tag);
        if (result != null) return result;
      }
    }
    return null;
  }

  List<VmlElement> querySelectorAll(String tag) {
    List<VmlElement> elements = [];
    if (tagName == tag) elements.add(this);
    for (var child in children) {
      if (child is VmlElement) {
        elements.addAll(child.querySelectorAll(tag));
      }
    }
    return elements;
  }

  @override
  String toString() {
    String attrStr = attributes.isEmpty
        ? ''
        : ' ' + attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');
    
    if (children.isEmpty) {
      return '<$tagName$attrStr />';
    }
    return '<$tagName$attrStr>\n  ${children.join('\n').replaceAll('\n', '\n  ')}\n</$tagName>';
  }
}

class VmlDocument {
  final List<VmlNode> nodes;

  VmlDocument(this.nodes);

  static VmlDocument fromAst(List<Node> astNodes) {
    return VmlDocument(_convertNodes(astNodes));
  }

  static List<VmlNode> _convertNodes(List<Node> astNodes) {
    List<VmlNode> vmlNodes = [];
    for (var node in astNodes) {
      if (node is MarkupNode) {
        Map<String, dynamic> attrs = {};
        node.attributes.forEach((key, value) {
          attrs[key] = _evaluateAttribute(value);
        });
        vmlNodes.add(VmlElement(
          node.name,
          attributes: attrs,
          children: _convertNodes(node.children),
        ));
      } else if (node is MarkupTextNode) {
        vmlNodes.add(VmlText(node.text));
      }
    }
    return vmlNodes;
  }

  static dynamic _evaluateAttribute(Node node) {
    if (node is StringNode) return node.value;
    if (node is Number) return node.value;
    if (node is BooleanNode) return node.value;
    if (node is IdentifierNode) return node.name;
    if (node is VariableNode) return node.name;
    // For complex expressions, we might just return the AST representation 
    // unless we have an interpreter context.
    return node.toString();
  }

  @override
  String toString() {
    return nodes.join('\n');
  }
}
