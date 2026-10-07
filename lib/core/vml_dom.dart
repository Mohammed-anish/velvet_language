import 'package:velvet_cmp/parser/ast_classes.dart';

abstract class VmlNode {
  VmlElement? parent;

  VmlNode? get next {
    if (parent == null) return null;
    var idx = parent!.children.indexOf(this);
    if (idx != -1 && idx < parent!.children.length - 1) {
      return parent!.children[idx + 1];
    }
    return null;
  }

  VmlNode? get prev {
    if (parent == null) return null;
    var idx = parent!.children.indexOf(this);
    if (idx > 0) {
      return parent!.children[idx - 1];
    }
    return null;
  }
}

class VmlText extends VmlNode {
  String text;

  VmlText(this.text);

  @override
  String toString() => text;
}

class VmlElement extends VmlNode {
  final String tagName;
  final Map<String, dynamic> attributes;
  final List<VmlNode> children;
  final Map<String, List<dynamic>> listeners = {};

  void on(String event, dynamic callback) {
    if (!listeners.containsKey(event)) {
      listeners[event] = [];
    }
    listeners[event]!.add(callback);
  }

  VmlElement(this.tagName,
      {Map<String, dynamic>? attributes, List<VmlNode>? children})
      : attributes = attributes ?? {},
        children = children ?? [] {
    for (var child in this.children) {
      child.parent = this;
    }
  }

  VmlElement? findId(String id) {
    if (attributes['id'] == id) return this;
    for (var child in children) {
      if (child is VmlElement) {
        var result = child.findId(id);
        if (result != null) return result;
      }
    }
    return null;
  }

  List<VmlElement> findGroup(String group) {
    List<VmlElement> elements = [];
    var grpAttr = attributes['group']?.toString() ?? '';
    if (grpAttr.split(RegExp(r'\s+')).contains(group)) {
      elements.add(this);
    }
    for (var child in children) {
      if (child is VmlElement) {
        elements.addAll(child.findGroup(group));
      }
    }
    return elements;
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

  void setAttr(String name, dynamic value) {
    attributes[name] = value;
  }

  void removeAttr(String name) {
    attributes.remove(name);
  }

  void append(VmlNode node) {
    node.parent = this;
    children.add(node);
  }

  void remove(VmlNode node) {
    if (children.remove(node)) {
      node.parent = null;
    }
  }

  void setText(String text) {
    children.clear();
    var textNode = VmlText(text);
    textNode.parent = this;
    children.add(textNode);
  }

  @override
  String toString() {
    String attrStr = attributes.isEmpty
        ? ''
        : ' ' +
            attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');

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
