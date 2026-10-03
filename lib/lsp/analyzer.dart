import 'package:velvet_cmp/core/types.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:lsp_server/lsp_server.dart';

enum VelvetSymbolKind { variable, function, class_, parameter, field, method }

class VelvetSymbol {
  final String name;
  final VelvetSymbolKind kind;
  final String detail;
  final String? docComment;
  final Range range;
  final String? type;

  VelvetSymbol({
    required this.name,
    required this.kind,
    required this.detail,
    this.docComment,
    required this.range,
    this.type,
  });
}

class Scope {
  final Scope? parent;
  final Range range;
  final Map<String, VelvetSymbol> symbols = {};

  Scope({this.parent, required this.range});

  void define(VelvetSymbol symbol) {
    symbols[symbol.name] = symbol;
  }

  VelvetSymbol? lookup(String name) {
    if (symbols.containsKey(name)) return symbols[name];
    if (parent != null) return parent!.lookup(name);
    return null;
  }

  List<VelvetSymbol> allSymbols() {
    final list = <VelvetSymbol>[];
    list.addAll(symbols.values);
    if (parent != null) list.addAll(parent!.allSymbols());
    return list;
  }
}

class SemanticToken {
  final int line;
  final int startChar;
  final int length;
  final int tokenType; // 0 = variable, 1 = function, 2 = class

  SemanticToken({
    required this.line,
    required this.startChar,
    required this.length,
    required this.tokenType,
  });
}

class ClassMember {
  final String name;
  final bool isStatic;
  final bool isMethod;
  final String detail;
  final String? docComment;
  final List<String> parameters;
  final String? returnType;

  ClassMember({
    required this.name,
    required this.isStatic,
    required this.isMethod,
    required this.detail,
    this.docComment,
    this.parameters = const [],
    this.returnType,
  });
}

class ClassDefinition {
  final String name;
  final String? docComment;
  final List<ClassMember> members = [];
  final Range range;

  ClassDefinition({required this.name, this.docComment, required this.range});
}

class VarDeclaration {
  final String name;
  final String inferredType;

  VarDeclaration({required this.name, required this.inferredType});
}

class SymbolOccurrence {
  final String name;
  final Range range;
  final VelvetSymbol? resolvedSymbol;

  SymbolOccurrence({required this.name, required this.range, this.resolvedSymbol});
}

class Analyzer {
  List<VelvetSymbol> symbols = [];
  List<SemanticToken> semanticTokens = [];
  List<ClassDefinition> classes = [];
  List<VarDeclaration> variables = [];
  List<SymbolOccurrence> occurrences = [];

  Scope? globalScope;
  Scope? currentScope;
  final Map<String, Scope> scopesByRange = {};

  void analyzeAST(Programe program) {
    symbols.clear();
    semanticTokens.clear();
    classes.clear();
    variables.clear();
    occurrences.clear();
    scopesByRange.clear();

    globalScope = Scope(
      range: Range(
        start: Position(line: 0, character: 0),
        end: Position(line: 999999, character: 999999),
      ),
    );
    currentScope = globalScope;

    for (var node in program.body) {
      _visit(node);
    }
  }

  Scope? scopeAt(Position pos) {
    Scope? deepest = globalScope;
    void search(Scope scope) {
      if (_contains(scope.range, pos)) {
        deepest = scope;
        // Search children by inspecting scopesByRange
      }
    }
    for (var s in scopesByRange.values) {
      if (_contains(s.range, pos)) {
        if (deepest == null || _contains(deepest!.range, s.range.start)) {
          deepest = s;
        }
      }
    }
    return deepest;
  }

  bool _contains(Range range, Position pos) {
    if (pos.line < range.start.line || pos.line > range.end.line) return false;
    if (pos.line == range.start.line && pos.character < range.start.character) return false;
    if (pos.line == range.end.line && pos.character > range.end.character) return false;
    return true;
  }

  void _pushScope(Range range) {
    final s = Scope(parent: currentScope, range: range);
    currentScope = s;
    scopesByRange['${range.start.line}:${range.start.character}-${range.end.line}:${range.end.character}'] = s;
  }

  void _popScope() {
    if (currentScope?.parent != null) {
      currentScope = currentScope!.parent;
    }
  }

  Range _range(Node node) {
    int startLine = node.line > 0 ? node.line - 1 : 0;
    int startChar = node.column > 0 ? node.column - 1 : 0;
    int endLine = node.endLine > 0 ? node.endLine - 1 : startLine;
    int endChar = node.endColumn > 0 ? node.endColumn - 1 : startChar + 1;
    return Range(
      start: Position(line: startLine, character: startChar),
      end: Position(line: endLine, character: endChar),
    );
  }

  Range _nameRange(Node node, String name) {
    int startLine = node.line > 0 ? node.line - 1 : 0;
    int startChar = node.column > 0 ? node.column - 1 : 0;
    return Range(
      start: Position(line: startLine, character: startChar),
      end: Position(line: startLine, character: startChar + name.length),
    );
  }

  void _addSymbol(VelvetSymbol symbol) {
    symbols.add(symbol); // Global flat list for backwards compatibility
    currentScope?.define(symbol);
  }

  void _visit(Node node) {
    if (node is ClassDeclration) {
      _visitClass(node);
    } else if (node is FunctionDecl) {
      _visitFunction(node);
    } else if (node is VariableDeclarationNode) {
      _visitVariable(node);
    } else if (node is BlockNode) {
      _pushScope(_range(node));
      for (var stmt in node.statements) {
        _visit(stmt);
      }
      _popScope();
    } else if (node is IfNode) {
      _visit(node.condition);
      _pushScope(_range(node));
      for (var stmt in node.ifBlock) {
        _visit(stmt);
      }
      _popScope();
      if (node.elseNode != null) {
        _pushScope(_range(node));
        for (var stmt in node.elseNode!) {
          _visit(stmt);
        }
        _popScope();
      }
    } else if (node is WhileNode) {
      _visit(node.condition);
      _pushScope(_range(node));
      for (var stmt in node.body) {
        _visit(stmt);
      }
      _popScope();
    } else if (node is ForNode) {
      _pushScope(_range(node));
      if (node.init != null) _visit(node.init!);
      if (node.condition != null) _visit(node.condition!);
      if (node.update != null) _visit(node.update!);
      for (var stmt in node.body) {
        _visit(stmt);
      }
      _popScope();
    } else if (node is ReturnNode) {
      _visit(node.value);
    } else if (node is AssignmentNode) {
      _visit(node.target);
      _visit(node.value);
    } else if (node is FunctionCall) {
      _visit(node.callee);
      for (var arg in node.arguments) {
        _visit(arg);
      }
    } else if (node is MemberAccess) {
      _visit(node.object);
      _recordOccurrence(node.property, _range(node), isMember: true);
    } else if (node is VariableNode) {
      _recordOccurrence(node.name, _range(node));
    } else if (node is IdentifierNode) {
      _recordOccurrence(node.name, _range(node));
    } else if (node is BineryNode) {
      _visit(node.left);
      _visit(node.right);
    } else if (node is ExpressionStatement) {
      _visit(node.value);
    }
  }

  void _visitClass(ClassDeclration node) {
    final classRange = _range(node);
    final nameRange = _nameRange(node, node.name);
    
    final sym = VelvetSymbol(
      name: node.name,
      kind: VelvetSymbolKind.class_,
      detail: 'Class: ${node.name}',
      range: nameRange,
      type: node.name,
    );
    _addSymbol(sym);

    final classDef = ClassDefinition(
      name: node.name,
      range: classRange,
    );
    classes.add(classDef);

    _pushScope(classRange);
    
    // Add "this"
    currentScope?.define(VelvetSymbol(
      name: 'this',
      kind: VelvetSymbolKind.variable,
      detail: 'Instance of ${node.name}',
      range: classRange,
      type: node.name,
    ));

    for (var stmt in node.body) {
      if (stmt is FunctionDecl) {
        classDef.members.add(ClassMember(
          name: stmt.name,
          isStatic: stmt.isStatic,
          isMethod: true,
          detail: '${stmt.isStatic ? "Static " : ""}Method: ${stmt.name}()',
          parameters: stmt.arguments,
          returnType: stmt.returnType is IdentifierNode ? (stmt.returnType as IdentifierNode).name : null,
        ));
        _visitFunction(stmt, isMember: true);
      } else if (stmt is VariableDeclarationNode) {
        String type = _inferTypeFromNode(stmt.value);
        if (stmt.kind != 'auto') type = stmt.kind;

        classDef.members.add(ClassMember(
          name: stmt.name,
          isStatic: stmt.isStatic,
          isMethod: false,
          detail: '${stmt.isStatic ? "Static " : ""}Field: ${stmt.name}',
          returnType: type,
        ));
        _visitVariable(stmt, isMember: true);
      }
    }
    _popScope();
    
    _recordSemanticToken(nameRange, 2); // class
  }

  void _visitFunction(FunctionDecl node, {bool isMember = false}) {
    final funcRange = _range(node);
    final nameRange = _nameRange(node, node.name);
    
    final sym = VelvetSymbol(
      name: node.name,
      kind: isMember ? VelvetSymbolKind.method : VelvetSymbolKind.function,
      detail: '${isMember ? "Method" : "Function"}: ${node.name}(${node.arguments.join(", ")})',
      range: nameRange,
      type: node.returnType is IdentifierNode ? (node.returnType as IdentifierNode).name : null,
    );
    _addSymbol(sym);

    _pushScope(funcRange);
    
    for (var arg in node.arguments) {
      final argRange = Range(start: nameRange.start, end: nameRange.start); 
      currentScope?.define(VelvetSymbol(
        name: arg,
        kind: VelvetSymbolKind.parameter,
        detail: 'Parameter: $arg',
        range: argRange,
      ));
    }

    for (var stmt in node.body) {
      _visit(stmt);
    }
    _popScope();

    _recordSemanticToken(nameRange, 1); // function
  }

  void _visitVariable(VariableDeclarationNode node, {bool isMember = false}) {
    final nameRange = _nameRange(node, node.name);
    String type = _inferTypeFromNode(node.value);
    if (node.kind != 'auto') {
      type = node.kind;
    }

    final sym = VelvetSymbol(
      name: node.name,
      kind: isMember ? VelvetSymbolKind.field : VelvetSymbolKind.variable,
      detail: '$type ${node.name}',
      range: nameRange,
      type: type,
    );
    _addSymbol(sym);
    
    if (!isMember) {
      variables.add(VarDeclaration(name: node.name, inferredType: type));
    }

    _visit(node.value);
    
    _recordSemanticToken(nameRange, 0); // variable
  }

  String _inferTypeFromNode(Node node) {
    if (node is StringNode) return 'String';
    if (node is Number) return 'Number';
    if (node is BooleanNode) return 'Boolean';
    if (node is ArrayNode) return 'List';
    if (node is MapNode) return 'Map';
    if (node is NewClassInstance) return node.name;
    return 'dynamic';
  }

  void _recordOccurrence(String name, Range range, {bool isMember = false}) {
    VelvetSymbol? resolved = currentScope?.lookup(name);
    occurrences.add(SymbolOccurrence(name: name, range: range, resolvedSymbol: resolved));
    
    if (!isMember) {
      int type = 0;
      if (resolved != null) {
        if (resolved.kind == VelvetSymbolKind.class_) type = 2;
        if (resolved.kind == VelvetSymbolKind.function || resolved.kind == VelvetSymbolKind.method) type = 1;
      }
      _recordSemanticToken(range, type);
    }
  }

  void _recordSemanticToken(Range range, int tokenType) {
    semanticTokens.add(SemanticToken(
      line: range.start.line,
      startChar: range.start.character,
      length: range.end.character - range.start.character,
      tokenType: tokenType,
    ));
  }

  List<int> getEncodedSemanticTokens() {
    semanticTokens.sort((a, b) {
      if (a.line != b.line) return a.line.compareTo(b.line);
      return a.startChar.compareTo(b.startChar);
    });

    List<int> data = [];
    int prevLine = 0;
    int prevChar = 0;

    for (var token in semanticTokens) {
      if (token.length <= 0) continue;
      int deltaLine = token.line - prevLine;
      int deltaChar = deltaLine == 0
          ? token.startChar - prevChar
          : token.startChar;

      data.add(deltaLine);
      data.add(deltaChar);
      data.add(token.length);
      data.add(token.tokenType);
      data.add(0); // modifiers (none)

      prevLine = token.line;
      prevChar = token.startChar;
    }

    return data;
  }
}
