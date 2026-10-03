import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';
import 'package:velvet_cmp/core/bundled_core.dart';
import 'package:velvet_cmp/core/types.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'analyzer.dart';

class LspHandlers {
  final Connection connection;

  final Map<String, String> documents = {};
  final Map<String, Analyzer> documentAnalyzers = {};
  final Map<String, ClassDefinition> globalClasses = {};
  final Map<String, String> globalClassModules = {};
  final Set<String> coreLibraries = {};
  final Set<String> workspaceRoots = {};

  LspHandlers(this.connection) {
    _registerHandlers();
  }

  void _indexVelvetCore([String? documentUri]) {
    if (globalClasses.isNotEmpty) return;
    try {
      for (var entry in BundledCore.files.entries) {
        final libName = entry.key; // e.g. "socket", "os"
        final content = entry.value;
        coreLibraries.add(libName);

        final tokenizer = Tokenizer(content);
        tokenizer.tokenize();
        final parser = Parser(tokenizer);
        final program = parser.parse();
        final analyzer = Analyzer();
        analyzer.analyzeAST(program);

        for (var clazz in analyzer.classes) {
          globalClasses[clazz.name] = clazz;
          globalClassModules[clazz.name] = libName;
        }
      }
    } catch (_) {}
  }

  void _registerHandlers() {
    connection.onInitialize((params) async {
      _indexVelvetCore();
      _indexWorkspace(params);
      return InitializeResult(
        capabilities: ServerCapabilities(
          textDocumentSync: Either2.t1(TextDocumentSyncKind.Full),
          completionProvider: CompletionOptions(
            resolveProvider: false,
            triggerCharacters: ['.', '"', "'", '/'],
          ),
          hoverProvider: Either2.t1(true),
          definitionProvider: Either2.t1(true),
          referencesProvider: Either2.t1(true),
          renameProvider: Either2.t1(true),
          documentSymbolProvider: Either2.t1(true),
          workspaceSymbolProvider: Either2.t1(true),
          documentFormattingProvider: Either2.t1(true),
          codeActionProvider: Either2.t1(true),
          semanticTokensProvider: Either2.t1(
            SemanticTokensOptions(
              legend: SemanticTokensLegend(
                tokenTypes: ['variable', 'function', 'class'],
                tokenModifiers: [],
              ),
              full: Either2.t1(true),
            ),
          ),
        ),
      );
    });

    connection.onCompletion((params) async {
      final uri = params.textDocument.uri.toString();
      final position = params.position;
      _indexVelvetCore(uri);
      final text = documents[uri];
      if (text != null) {
        final lines = text.split('\n');
        if (position.line >= 0 && position.line < lines.length) {
          final lineText = lines[position.line];
          if (_isImportContext(lineText, position.character)) {
            final importCompletions = _getImportCompletions(uri);
            return CompletionList(
              isIncomplete: false,
              items: importCompletions,
            );
          }
        }
        final dotResult = _getDotCompletionContext(text, position);
        if (dotResult != null) {
          final receiver = dotResult.receiver;
          final type = _inferType(uri, receiver);
          if (type != null) {
            final items = _getMembersForType(uri, type, dotResult.isStaticOnly);
            return CompletionList(isIncomplete: false, items: items);
          }
        }
      }
      List<CompletionItem> items = [
        CompletionItem(
          label: 'auto',
          kind: CompletionItemKind.Keyword,
          detail: 'Variable declaration',
        ),
        CompletionItem(
          label: 'fn',
          kind: CompletionItemKind.Keyword,
          detail: 'Function declaration',
        ),
        CompletionItem(
          label: 'async',
          kind: CompletionItemKind.Keyword,
          detail: 'Async modifier',
        ),
        CompletionItem(
          label: 'await',
          kind: CompletionItemKind.Keyword,
          detail: 'Await expression',
        ),
        CompletionItem(
          label: 'class',
          kind: CompletionItemKind.Keyword,
          detail: 'Class declaration',
        ),
        CompletionItem(
          label: 'if',
          kind: CompletionItemKind.Keyword,
          detail: 'If statement',
        ),
        CompletionItem(
          label: 'else',
          kind: CompletionItemKind.Keyword,
          detail: 'Else statement',
        ),
        CompletionItem(
          label: 'while',
          kind: CompletionItemKind.Keyword,
          detail: 'While loop',
        ),
        CompletionItem(
          label: 'for',
          kind: CompletionItemKind.Keyword,
          detail: 'For loop',
        ),
        CompletionItem(
          label: 'return',
          kind: CompletionItemKind.Keyword,
          detail: 'Return statement',
        ),
      ];
      final analyzer = documentAnalyzers[uri];
      if (analyzer != null) {
        final scope = analyzer.scopeAt(position);
        final visibleSymbols =
            scope != null ? scope.allSymbols() : analyzer.symbols;
        for (var symbol in visibleSymbols) {
          CompletionItemKind kind = CompletionItemKind.Variable;
          if (symbol.kind == VelvetSymbolKind.function ||
              symbol.kind == VelvetSymbolKind.method) {
            kind = CompletionItemKind.Function;
          } else if (symbol.kind == VelvetSymbolKind.class_) {
            kind = CompletionItemKind.Class;
          } else if (symbol.kind == VelvetSymbolKind.field) {
            kind = CompletionItemKind.Field;
          }
          if (!items.any((item) => item.label == symbol.name)) {
            items.add(
              CompletionItem(
                label: symbol.name,
                kind: kind,
                detail: symbol.detail,
              ),
            );
          }
        }
        for (var className in globalClasses.keys) {
          if (!items.any((item) => item.label == className)) {
            final edit = _autoImportEdit(uri, className);
            items.add(
              CompletionItem(
                label: className,
                kind: CompletionItemKind.Class,
                detail: 'Core Class: $className',
                insertText: className,
                additionalTextEdits: edit.isNotEmpty ? edit : null,
              ),
            );
          }
        }
      }

      for (final entry in documentAnalyzers.entries) {
        if (entry.key == uri) continue;
        final globalScope = entry.value.globalScope;
        final globalSymbols = globalScope != null
            ? globalScope.allSymbols()
            : entry.value.symbols;
        for (final symbol in globalSymbols) {
          if (!items.any((item) => item.label == symbol.name)) {
            items.add(
              CompletionItem(
                label: symbol.name,
                kind: symbol.kind == VelvetSymbolKind.function
                    ? CompletionItemKind.Function
                    : symbol.kind == VelvetSymbolKind.class_
                        ? CompletionItemKind.Class
                        : CompletionItemKind.Variable,
                detail: '${symbol.detail} (workspace)',
              ),
            );
          }
        }
      }
      return CompletionList(isIncomplete: false, items: items);
    });

    connection.onHover((params) async {
      final uri = params.textDocument.uri.toString();
      final position = params.position;
      final text = documents[uri];
      if (text != null) {
        final word = _getWordAtPosition(text, position);
        if (word != null) {
          if (globalClasses.containsKey(word)) {
            final clazz = globalClasses[word]!;
            final md = clazz.docComment != null
                ? '${clazz.docComment}\n\n```velvet\nCore Class: $word\n```'
                : '```velvet\nCore Class: $word\n```';
            return Hover(
              contents: Either2.t1(
                MarkupContent(kind: MarkupKind.Markdown, value: md),
              ),
            );
          }

          final analyzer = documentAnalyzers[uri];
          if (analyzer != null) {
            for (var occurrence in analyzer.occurrences) {
              if (_isPositionInRange(occurrence.range, position)) {
                if (occurrence.resolvedSymbol != null) {
                  final sym = occurrence.resolvedSymbol!;
                  final md = sym.docComment != null
                      ? '${sym.docComment}\n\n```velvet\n${sym.detail}\n```'
                      : '```velvet\n${sym.detail}\n```';
                  return Hover(
                    contents: Either2.t1(
                        MarkupContent(kind: MarkupKind.Markdown, value: md)),
                  );
                }
                break;
              }
            }
            final scope = analyzer.scopeAt(position);
            if (scope != null) {
              final sym = scope.lookup(word);
              if (sym != null) {
                final md = sym.docComment != null
                    ? '${sym.docComment}\n\n```velvet\n${sym.detail}\n```'
                    : '```velvet\n${sym.detail}\n```';
                return Hover(
                  contents: Either2.t1(
                      MarkupContent(kind: MarkupKind.Markdown, value: md)),
                );
              }
            }
          }
        }
      }
      return Hover(
        contents: Either2.t1(
          MarkupContent(kind: MarkupKind.Markdown, value: ''),
        ),
      );
    });

    connection.onDefinition((params) async {
      final uri = params.textDocument.uri.toString();
      final position = params.position;
      final text = documents[uri];
      if (text != null) {
        final word = _getWordAtPosition(text, position);
        if (word != null) {
          final result = _resolveSymbolAtPosition(uri, position, word);
          if (result != null) {
            return Either3.t1(Location(
                uri: Uri.parse(result.key), range: result.value.range));
          }
        }
      }
      return null;
    });

    connection.onReferences((params) async {
      final uri = params.textDocument.uri.toString();
      final word = _wordForRequest(uri, params.position);
      if (word == null) return [];
      final result = _resolveSymbolAtPosition(uri, params.position, word);
      if (result == null) return [];
      return _locationsFor(result.value);
    });

    connection.onPrepareRename((params) async {
      final uri = params.textDocument.uri.toString();
      final word = _wordForRequest(uri, params.position);
      if (word == null || _isKeyword(word))
        return Either2.t1(Range(start: params.position, end: params.position));
      final range = _rangeForWord(uri, params.position);
      if (range != null) {
        return Either2.t1(range);
      }
      return Either2.t1(Range(start: params.position, end: params.position));
    });

    connection.onRenameRequest((params) async {
      final uri = params.textDocument.uri.toString();
      final word = _wordForRequest(uri, params.position);
      final newName = params.newName;
      if (word == null || !_isIdentifier(newName) || _isKeyword(newName)) {
        return WorkspaceEdit();
      }
      final result = _resolveSymbolAtPosition(uri, params.position, word);
      if (result == null) return WorkspaceEdit();
      final symbol = result.value;

      final changes = <Uri, List<TextEdit>>{};
      for (final entry in documentAnalyzers.entries) {
        final edits = <TextEdit>[];
        for (final sym in entry.value.symbols) {
          if (_isSameSymbol(sym, symbol)) {
            edits.add(TextEdit(range: sym.range, newText: newName));
          }
        }
        for (final occurrence in entry.value.occurrences) {
          if (_isSameSymbol(occurrence.resolvedSymbol, symbol)) {
            edits.add(TextEdit(range: occurrence.range, newText: newName));
          }
        }
        if (edits.isNotEmpty) changes[Uri.parse(entry.key)] = edits;
      }
      return WorkspaceEdit(changes: changes);
    });

    connection.onDocumentSymbol((params) async {
      final uri = params.textDocument.uri.toString();
      final analyzer = documentAnalyzers[uri];
      final symbols = analyzer?.symbols
              .map(
                (symbol) => SymbolInformation(
                  name: symbol.name,
                  containerName: symbol.detail,
                  kind: _lspSymbolKind(symbol.kind),
                  location: Location(uri: Uri.parse(uri), range: symbol.range),
                ),
              )
              .toList() ??
          [];
      return symbols;
    });

    connection.peer.registerMethod('workspace/symbol', (params) async {
      final query = (params.value['query'] as String? ?? '').toLowerCase();
      final results = <SymbolInformation>[];
      for (final entry in documentAnalyzers.entries) {
        for (final symbol in entry.value.symbols) {
          if (query.isEmpty || symbol.name.toLowerCase().contains(query)) {
            results.add(
              SymbolInformation(
                name: symbol.name,
                kind: _lspSymbolKind(symbol.kind),
                location: Location(
                  uri: Uri.parse(entry.key),
                  range: symbol.range,
                ),
                containerName: symbol.detail,
              ),
            );
          }
        }
      }
      return results;
    });

    connection.onDocumentFormatting((params) async {
      final uri = params.textDocument.uri.toString();
      final source = documents[uri];
      return source == null ? [] : _formatEdits(source);
    });

    connection.peer.registerMethod('textDocument/semanticTokens/full', (
      params,
    ) async {
      final uri = params.value['textDocument']['uri'] as String;
      final analyzer = documentAnalyzers[uri];
      if (analyzer != null) {
        return {'data': analyzer.getEncodedSemanticTokens()};
      }
      return {'data': []};
    });

    connection.onCodeAction((params) async {
      final uri = params.textDocument.uri.toString();
      final diagnostics = params.context.diagnostics;
      final actions = <CodeAction>[];
      for (var d in diagnostics) {
        final message = d.message;
        final match = RegExp(
          r'Undefined class (.+)\. Add import "(.+)"\.',
        ).firstMatch(message);
        if (match != null) {
          final module = match.group(2)!;
          actions.add(
            CodeAction(
              title: 'Import "$module"',
              kind: CodeActionKind.QuickFix,
              diagnostics: [d],
              edit: WorkspaceEdit(
                changes: {
                  Uri.parse(uri): [
                    TextEdit(
                      range: Range(
                        start: Position(line: 0, character: 0),
                        end: Position(line: 0, character: 0),
                      ),
                      newText: 'import "$module"\n',
                    ),
                  ],
                },
              ),
            ),
          );
        }
      }
      return actions;
    });

    connection.onDidOpenTextDocument((params) async {
      final uri = params.textDocument.uri.toString();
      final text = params.textDocument.text;
      documents[uri] = text;
      _validateDocument(uri, text);
    });

    connection.onDidChangeTextDocument((params) async {
      final uri = params.textDocument.uri.toString();
      final changes = params.contentChanges;
      if (changes.isNotEmpty) {
        final text = changes[0].map((c1) => c1.text, (c2) => c2.text);
        documents[uri] = text;
        _validateDocument(uri, text);
      }
    });

    connection.onDidCloseTextDocument((params) async {
      final uri = params.textDocument.uri.toString();
      documents.remove(uri);
      documentAnalyzers.remove(uri);
    });
  }

  void _indexWorkspace(dynamic initializeParams) {
    if (initializeParams is! Map) return;
    final folders = initializeParams['workspaceFolders'] as List?;
    if (folders == null) return;
    for (final folder in folders) {
      if (folder is! Map || folder['uri'] is! String) continue;
      try {
        final root = Uri.parse(folder['uri'] as String);
        if (!root.isScheme('file') || !workspaceRoots.add(root.toFilePath())) {
          continue;
        }
        final directory = Directory(root.toFilePath());
        if (!directory.existsSync()) continue;
        final allFiles =
            directory.listSync(recursive: true, followLinks: false);
        final actionFiles = <File>[];
        final regularFiles = <File>[];

        for (final entity in allFiles) {
          if (entity is File && entity.path.endsWith('.velv')) {
            if (entity.path.endsWith('.action.velv')) {
              actionFiles.add(entity);
            } else {
              regularFiles.add(entity);
            }
          }
        }

        for (final file in actionFiles) {
          final uri = file.uri.toString();
          final source = file.readAsStringSync();
          documents.putIfAbsent(uri, () => source);
          _analyzeDocument(uri, source);
        }

        for (final file in regularFiles) {
          final uri = file.uri.toString();
          final source = file.readAsStringSync();
          documents.putIfAbsent(uri, () => source);
          _analyzeDocument(uri, source);
        }
      } catch (_) {
        // A workspace can contain unreadable folders; leave them out of the index.
      }
    }
  }

  void _analyzeDocument(String uri, String text) {
    try {
      final tokenizer = Tokenizer(text)..tokenize();
      final parser = Parser(tokenizer);
      final program = parser.parse();
      final analyzer = Analyzer()..analyzeAST(program);
      documentAnalyzers[uri] = analyzer;
    } catch (_) {
      // Keep the previous usable index while a file is being edited.
    }
  }

  bool _isPositionInRange(Range range, Position pos) {
    if (pos.line < range.start.line || pos.line > range.end.line) return false;
    if (pos.line == range.start.line && pos.character < range.start.character)
      return false;
    if (pos.line == range.end.line && pos.character > range.end.character)
      return false;
    return true;
  }

  MapEntry<String, VelvetSymbol>? _resolveSymbolAtPosition(
      String currentUri, Position position, String word) {
    final analyzer = documentAnalyzers[currentUri];
    if (analyzer != null) {
      for (var occurrence in analyzer.occurrences) {
        if (_isPositionInRange(occurrence.range, position)) {
          if (occurrence.resolvedSymbol != null) {
            return MapEntry(currentUri, occurrence.resolvedSymbol!);
          }
          break;
        }
      }

      final scope = analyzer.scopeAt(position);
      if (scope != null) {
        final sym = scope.lookup(word);
        if (sym != null) {
          return MapEntry(currentUri, sym);
        }
      }
    }

    for (final entry in documentAnalyzers.entries) {
      final a = entry.value;
      if (a.globalScope != null) {
        final sym = a.globalScope!.lookup(word);
        if (sym != null) {
          return MapEntry(entry.key, sym);
        }
      }
      for (final sym in a.symbols) {
        if (sym.name == word) {
          return MapEntry(entry.key, sym);
        }
      }
    }
    return null;
  }

  bool _isSameSymbol(VelvetSymbol? a, VelvetSymbol? b) {
    if (a == null || b == null) return false;
    if (identical(a, b)) return true;
    return a.name == b.name &&
        a.range.start.line == b.range.start.line &&
        a.range.start.character == b.range.start.character;
  }

  List<Location> _locationsFor(VelvetSymbol target) {
    final locations = <Location>[];
    for (final entry in documentAnalyzers.entries) {
      for (final occurrence in entry.value.occurrences) {
        if (_isSameSymbol(occurrence.resolvedSymbol, target)) {
          locations.add(
            Location(uri: Uri.parse(entry.key), range: occurrence.range),
          );
        }
      }
    }
    return locations;
  }

  String? _wordForRequest(String uri, Position position) =>
      documents[uri] == null
          ? null
          : _getWordAtPosition(documents[uri]!, position);

  Range? _rangeForWord(String uri, Position position) {
    final analyzer = documentAnalyzers[uri];
    if (analyzer == null) return null;
    for (final occurrence in analyzer.occurrences) {
      if (occurrence.range.start.line == position.line &&
          occurrence.range.start.character <= position.character &&
          occurrence.range.end.character >= position.character) {
        return occurrence.range;
      }
    }
    return null;
  }

  bool _isIdentifier(String value) =>
      RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value);

  bool _isKeyword(String value) => const {
        'fn',
        'class',
        'auto',
        'let',
        'const',
        'if',
        'else',
        'while',
        'for',
        'return',
        'import',
        'export',
        'new',
        'static',
        'async',
        'await',
        'true',
        'false',
        'null',
        'this',
        'outer',
        'state',
        'try',
        'catch',
        'throw',
      }.contains(value);

  SymbolKind _lspSymbolKind(VelvetSymbolKind kind) {
    if (kind == VelvetSymbolKind.function) return SymbolKind.Function;
    if (kind == VelvetSymbolKind.class_) return SymbolKind.Class;
    return SymbolKind.Variable;
  }

  List<TextEdit> _formatEdits(String source) {
    final normalized =
        source.split('\n').map((line) => line.trimRight()).join('\n');
    final formatted = normalized.endsWith('\n') ? normalized : '$normalized\n';
    if (formatted == source) return [];
    final lineCount = source.split('\n').length;
    return [
      TextEdit(
        range: Range(
          start: Position(line: 0, character: 0),
          end: Position(line: lineCount, character: 0),
        ),
        newText: formatted,
      ),
    ];
  }

  String? _getWordAtPosition(String text, Position pos) {
    final lines = text.split('\n');
    if (pos.line < 0 || pos.line >= lines.length) return null;
    final lineText = lines[pos.line];
    if (pos.character < 0 || pos.character > lineText.length) return null;

    int start =
        pos.character == lineText.length ? pos.character - 1 : pos.character;
    if (start < 0) return null;
    while (start > 0 && RegExp(r'[a-zA-Z0-9_]').hasMatch(lineText[start - 1])) {
      start--;
    }
    int end = pos.character;
    while (end < lineText.length &&
        RegExp(r'[a-zA-Z0-9_]').hasMatch(lineText[end])) {
      end++;
    }

    if (start < end) {
      return lineText.substring(start, end);
    }
    return null;
  }

  DotContext? _getDotCompletionContext(String text, Position pos) {
    final lines = text.split('\n');
    if (pos.line < 0 || pos.line >= lines.length) return null;
    final lineText = lines[pos.line];
    if (pos.character <= 0 || pos.character > lineText.length) return null;

    int dotIdx = pos.character - 1;
    while (dotIdx >= 0 && lineText[dotIdx] != '.') {
      dotIdx--;
    }

    if (dotIdx >= 0 && lineText[dotIdx] == '.') {
      int start = dotIdx;
      while (start > 0 &&
          RegExp(r'[a-zA-Z0-9_().]').hasMatch(lineText[start - 1])) {
        start--;
      }
      if (start < dotIdx) {
        final receiver = lineText.substring(start, dotIdx);
        bool isStaticOnly = globalClasses.containsKey(receiver) ||
            (documentAnalyzers.values.any(
              (a) => a.classes.any((c) => c.name == receiver),
            ));
        return DotContext(receiver, isStaticOnly);
      }
    }
    return null;
  }

  String? _inferType(String uri, String receiver) {
    if (receiver.endsWith('.toString()')) return 'String';
    if (receiver.endsWith('.toInt()')) return 'Number';
    if (receiver.endsWith('.toDouble()')) return 'Number';

    // strip chained calls for basic inference if possible
    if (receiver.contains('.')) {
      receiver = receiver.split('.').first;
    }

    if (globalClasses.containsKey(receiver)) return receiver;

    final localAnalyzer = documentAnalyzers[uri];
    if (localAnalyzer != null) {
      if (localAnalyzer.classes.any((c) => c.name == receiver)) return receiver;

      for (var variable in localAnalyzer.variables) {
        if (variable.name == receiver) {
          return variable.inferredType;
        }
      }
    }

    final text = documents[uri];
    if (text != null) {
      final matchNew = RegExp(
        '\\b${RegExp.escape(receiver)}\\s*=\\s*(?:new\\s+)?([a-zA-Z0-9_]+)\\s*\\(',
      ).firstMatch(text);
      if (matchNew != null) {
        return matchNew.group(1);
      }
      final matchStr = RegExp(
        '\\b${RegExp.escape(receiver)}\\s*=\\s*["\']',
      ).firstMatch(text);
      if (matchStr != null) {
        return "String";
      }
      final matchArr = RegExp(
        '\\b${RegExp.escape(receiver)}\\s*=\\s*\\[',
      ).firstMatch(text);
      if (matchArr != null) {
        return "List";
      }
    }
    return null;
  }

  List<CompletionItem> _getMembersForType(
    String uri,
    String type,
    bool isStaticOnly,
  ) {
    List<CompletionItem> items = [];

    if (type == "String") {
      return _presentMethods([
        {
          'label': 'length',
          'kind': 10,
          'detail': 'String property: returns length',
          'insertText': 'length',
        },
        {
          'label': 'substring',
          'kind': 2,
          'detail': 'String method: substring(start, end)',
          'insertText': 'substring(\${1:start}, \${2:end})',
          'insertTextFormat': 2,
        },
        {
          'label': 'trim',
          'kind': 2,
          'detail': 'String method: removes whitespace',
          'insertText': 'trim()',
        },
        {
          'label': 'split',
          'kind': 2,
          'detail': 'String method: splits by separator',
          'insertText': 'split(\${1:separator})',
          'insertTextFormat': 2,
        },
        {
          'label': 'indexOf',
          'kind': 2,
          'detail': 'String method: finds pattern index',
          'insertText': 'indexOf(\${1:pattern})',
          'insertTextFormat': 2,
        },
        {
          'label': 'startsWith',
          'kind': 2,
          'detail': 'String method: checks prefix',
          'insertText': 'startsWith(\${1:prefix})',
          'insertTextFormat': 2,
        },
        {
          'label': 'endsWith',
          'kind': 2,
          'detail': 'String method: checks suffix',
          'insertText': 'endsWith(\${1:suffix})',
          'insertTextFormat': 2,
        },
        {
          'label': 'contains',
          'kind': 2,
          'detail': 'String method: checks substring',
          'insertText': 'contains(\${1:substring})',
          'insertTextFormat': 2,
        },
        {
          'label': 'toLowerCase',
          'kind': 2,
          'detail': 'String method: converts to lowercase',
          'insertText': 'toLowerCase()',
        },
        {
          'label': 'toUpperCase',
          'kind': 2,
          'detail': 'String method: converts to uppercase',
          'insertText': 'toUpperCase()',
        },
      ]);
    }

    if (type == "List") {
      return _presentMethods([
        {
          'label': 'length',
          'kind': 10,
          'detail': 'List property: returns size',
          'insertText': 'length',
        },
        {
          'label': 'add',
          'kind': 2,
          'detail': 'List method: appends value',
          'insertText': 'add(\${1:value})',
          'insertTextFormat': 2,
        },
        {
          'label': 'remove',
          'kind': 2,
          'detail': 'List method: removes value',
          'insertText': 'remove(\${1:value})',
          'insertTextFormat': 2,
        },
        {
          'label': 'removeAt',
          'kind': 2,
          'detail': 'List method: removes value at index',
          'insertText': 'removeAt(\${1:index})',
          'insertTextFormat': 2,
        },
        {
          'label': 'clear',
          'kind': 2,
          'detail': 'List method: clears all items',
          'insertText': 'clear()',
        },
        {
          'label': 'join',
          'kind': 2,
          'detail': 'List method: joins elements with separator',
          'insertText': 'join(\${1:separator})',
          'insertTextFormat': 2,
        },
        {
          'label': 'map',
          'kind': 2,
          'detail': 'List method: maps elements',
          'insertText': 'map(\${1:callback})',
          'insertTextFormat': 2,
        },
        {
          'label': 'filter',
          'kind': 2,
          'detail': 'List method: filters elements',
          'insertText': 'filter(\${1:callback})',
          'insertTextFormat': 2,
        },
        {
          'label': 'contains',
          'kind': 2,
          'detail': 'List method: checks if item exists',
          'insertText': 'contains(\${1:value})',
          'insertTextFormat': 2,
        },
      ]);
    }

    if (type == 'Number') {
      return _members([
        ['toString', 'Number method: converts to String', 'toString()'],
        ['toInt', 'Number method: converts to integer', 'toInt()'],
        ['toDouble', 'Number method: converts to decimal', 'toDouble()'],
        ['round', 'Number method: rounds to nearest integer', 'round()'],
        ['floor', 'Number method: rounds down', 'floor()'],
        ['ceil', 'Number method: rounds up', 'ceil()'],
        ['abs', 'Number method: absolute value', 'abs()'],
      ]);
    }

    if (type == 'Boolean') {
      return _members([
        ['toString', 'Boolean method: converts to String', 'toString()'],
      ]);
    }

    if (type == 'Map') {
      return _members([
        [
          'put',
          'Map method: stores a key/value pair',
          'put(\${1:key}, \${2:value})',
        ],
        ['get', 'Map method: returns a value by key', 'get(\${1:key})'],
        ['remove', 'Map method: removes a value by key', 'remove(\${1:key})'],
        [
          'containsKey',
          'Map method: checks for a key',
          'containsKey(\${1:key})',
        ],
        ['keys', 'Map method: returns all keys', 'keys()'],
        ['values', 'Map method: returns all values', 'values()'],
        ['clear', 'Map method: removes all entries', 'clear()'],
      ]);
    }

    ClassDefinition? classDef;
    final localAnalyzer = documentAnalyzers[uri];
    if (localAnalyzer != null) {
      for (var c in localAnalyzer.classes) {
        if (c.name == type) {
          classDef = c;
          break;
        }
      }
    }
    classDef ??= globalClasses[type];

    if (classDef != null) {
      for (var member in classDef.members) {
        if (isStaticOnly && !member.isStatic) continue;
        if (!isStaticOnly && member.isStatic) continue;

        int kind = member.isMethod ? 2 : 10;
        final insertText = member.isMethod
            ? _methodInsertText(member.name, member.parameters)
            : member.name;
        items.add(
          CompletionItem(
            label: member.isMethod
                ? '${member.name}(${member.parameters.join(', ')})'
                : member.name,
            kind: kind == 2
                ? CompletionItemKind.Method
                : CompletionItemKind.Property,
            detail: member.isMethod
                ? '(${member.parameters.join(', ')})'
                : member.detail,
            insertText: insertText,
            insertTextFormat: (member.isMethod && member.parameters.isNotEmpty)
                ? InsertTextFormat.Snippet
                : InsertTextFormat.PlainText,
          ),
        );
      }
    }

    return items;
  }

  List<CompletionItem> _members(List<List<String>> definitions) => definitions
      .map(
        (definition) => CompletionItem(
          label: definition[0],
          kind: CompletionItemKind.Method,
          detail: definition[1],
          insertText: definition[2],
          insertTextFormat: definition[2].contains(r'${')
              ? InsertTextFormat.Snippet
              : InsertTextFormat.PlainText,
        ),
      )
      .toList();

  List<CompletionItem> _presentMethods(List<Map<String, dynamic>> items) {
    for (final item in items) {
      if (item['kind'] != 2) continue;
      final originalName = item['label'] as String;
      final insertText = item['insertText'] as String? ?? '$originalName()';
      final signature = insertText.replaceAllMapped(
        RegExp(r'\$\{\d+:([^}]+)\}'),
        (match) => match.group(1)!,
      );
      item['label'] = signature;
      item['filterText'] = originalName;
      item['documentation'] = item['detail'];
      item['detail'] = signature.substring(originalName.length);
    }
    return items
        .map(
          (e) => CompletionItem(
            label: e['label'] as String,
            kind: e['kind'] == 2
                ? CompletionItemKind.Method
                : CompletionItemKind.Property,
            detail: e['detail'] as String?,
            documentation: e['documentation'] != null
                ? Either2<MarkupContent, String>.t2(
                    e['documentation'] as String,
                  )
                : null,
            filterText: e['filterText'] as String?,
            insertText: e['insertText'] as String?,
            insertTextFormat: e['insertTextFormat'] == 2
                ? InsertTextFormat.Snippet
                : InsertTextFormat.PlainText,
          ),
        )
        .toList();
  }

  String _methodInsertText(String name, List<String> parameters) {
    if (parameters.isEmpty) return '$name()';
    final placeholders = parameters
        .asMap()
        .entries
        .map((entry) => '\${${entry.key + 1}:${entry.value}}')
        .join(', ');
    return '$name($placeholders)';
  }

  void _validateDocument(String uri, String text) {
    List<Diagnostic> diagnostics = [];
    List<Node> nodes = [];

    // Pre-parse action files in the same directory
    try {
      final parsedUri = Uri.parse(uri);
      if (parsedUri.isScheme('file')) {
        final file = File(parsedUri.toFilePath());
        final dir = file.parent;
        if (dir.existsSync()) {
          for (var entity in dir.listSync()) {
            if (entity is File && entity.path.endsWith('.action.velv')) {
              final actionTokenizer = Tokenizer(entity.readAsStringSync())
                ..tokenize();
              Parser(actionTokenizer).parse();
            }
          }
        }
      }
    } catch (_) {}

    final tokenizer = Tokenizer(text);

    try {
      tokenizer.tokenize();
      final parser = Parser(tokenizer);
      parser.parse();

      for (var error in parser.errors) {
        final pos = Position(
          line: error.line > 0 ? error.line - 1 : 0,
          character: error.column > 0 ? error.column - 1 : 0,
        );
        diagnostics.add(
          Diagnostic(
            range: Range(
              start: pos,
              end: Position(line: pos.line, character: pos.character + 1),
            ),
            severity: DiagnosticSeverity.Error,
            message: error.message.replaceAll('Exception: ', ''),
          ),
        );
      }
    } catch (e) {
      final errorMsg = e.toString();
      int line = 1;
      int char = 1;

      final match = RegExp(r'line\s+(\d+):(\d+)').firstMatch(errorMsg);
      if (match != null) {
        line = int.parse(match.group(1)!);
        char = int.parse(match.group(2)!);
      } else {
        final match2 = RegExp(r':\s*(\d+)').firstMatch(errorMsg);
        if (match2 != null) {
          line = int.parse(match2.group(1)!);
        }
      }

      final pos = Position(
        line: line > 0 ? line - 1 : 0,
        character: char > 0 ? char - 1 : 0,
      );
      diagnostics.add(
        Diagnostic(
          range: Range(
            start: pos,
            end: Position(line: pos.line, character: pos.character + 1),
          ),
          severity: DiagnosticSeverity.Error,
          message: errorMsg.replaceAll('Exception: ', ''),
        ),
      );
    }

    _indexVelvetCore(uri);
    diagnostics.addAll(_unimportedClassDiagnostics(text, tokenizer.tokens));
    diagnostics.addAll(_typeCheckDiagnostics(text));

    // Run the fuzzy token analyzer
    _analyzeDocument(uri, text);

    connection.peer.sendNotification('textDocument/publishDiagnostics', {
      'uri': uri,
      'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
    });
  }

  List<Diagnostic> _typeCheckDiagnostics(String text) {
    final diagnostics = <Diagnostic>[];
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Check Number assigned to string
      final numMatch = RegExp(
        r'''\bNumber\s+[a-zA-Z0-9_]+\s*=\s*["']''',
      ).firstMatch(line);
      if (numMatch != null) {
        diagnostics.add(
          Diagnostic(
            range: Range(
              start: Position(line: i, character: numMatch.start),
              end: Position(line: i, character: numMatch.end),
            ),
            severity: DiagnosticSeverity.Error,
            message: "Type error: Cannot assign a String to a Number.",
          ),
        );
      }
      // Check String assigned to number
      final strMatch = RegExp(
        r'''\bString\s+[a-zA-Z0-9_]+\s*=\s*-?[0-9]+(\.[0-9]+)?\b''',
      ).firstMatch(line);
      if (strMatch != null) {
        diagnostics.add(
          Diagnostic(
            range: Range(
              start: Position(line: i, character: strMatch.start),
              end: Position(line: i, character: strMatch.end),
            ),
            severity: DiagnosticSeverity.Error,
            message: "Type error: Cannot assign a Number to a String.",
          ),
        );
      }
    }
    return diagnostics;
  }

  List<Diagnostic> _unimportedClassDiagnostics(
    String source,
    List<Token> tokens,
  ) {
    final importedModules = RegExp(
      r'''^\s*import\s+["']([^"']+)["']''',
      multiLine: true,
    ).allMatches(source).map((match) => p.basename(match.group(1)!)).toSet();
    final diagnostics = <Diagnostic>[];
    final reported = <String>{};

    void checkClass(Token token) {
      final module = globalClassModules[token.value];
      if (module == null ||
          module == 'object.velv' ||
          importedModules.contains(module)) {
        return;
      }
      final key = '${token.line}:${token.column}';
      if (!reported.add(key)) return;
      final start = Position(line: token.line - 1, character: token.column - 1);
      diagnostics.add(
        Diagnostic(
          range: Range(
            start: start,
            end: Position(
              line: start.line,
              character: start.character + token.value.length,
            ),
          ),
          severity: DiagnosticSeverity.Error,
          message: 'Undefined class ${token.value}. Add import "$module".',
        ),
      );
    }

    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      if (token.type == TType.identifier) {
        final prev = index > 0 ? tokens[index - 1] : null;
        if (prev?.type == TType.class_ ||
            prev?.type == TType.fn ||
            prev?.type == TType.dot) {
          continue;
        }
        checkClass(token);
      }
    }
    return diagnostics;
  }

  bool _isImportContext(String lineText, int character) {
    final trimmed = lineText.trim();
    if (trimmed.startsWith('import')) {
      final afterImport = trimmed.substring(6).trim();
      if (afterImport.startsWith('"') ||
          afterImport.startsWith("'") ||
          afterImport.isEmpty) {
        return true;
      }
    }
    return false;
  }

  List<CompletionItem> _getImportCompletions(String documentUri) {
    final List<CompletionItem> completions = [];

    for (var lib in coreLibraries) {
      completions.add(
        CompletionItem(
          label: lib,
          kind: CompletionItemKind.File,
          detail: 'Core Library Module',
          insertText: lib,
        ),
      );
    }

    try {
      final uri = Uri.parse(documentUri);
      if (uri.isScheme('file')) {
        final docFile = File(uri.toFilePath());
        final dir = docFile.parent;
        if (dir.existsSync()) {
          for (var entity in dir.listSync()) {
            if (entity is File &&
                entity.path.endsWith('.velv') &&
                p.basename(entity.path) != p.basename(docFile.path)) {
              final filename = p.basename(entity.path);
              completions.add(
                CompletionItem(
                  label: filename,
                  kind: CompletionItemKind.File,
                  detail: 'Local Module',
                  insertText: filename,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    return completions;
  }

  /// Completion can edit the document as it inserts a symbol.  This mirrors
  /// the standard IDE behaviour for a class such as `DateTime` from os.velv.
  List<TextEdit> _autoImportEdit(String uri, String className) {
    final source = documents[uri];
    final module = globalClassModules[className];

    // modules are opt-in and must be written into the user's source file.
    if (module == null || module == 'object.velv' || source == null) return [];

    final escapedModule = RegExp.escape(module);
    if (RegExp(
      '^\\s*import\\s+["\\\']$escapedModule["\\\']',
      multiLine: true,
    ).hasMatch(source)) {
      return [];
    }

    return [
      TextEdit(
        range: Range(
          start: Position(line: 0, character: 0),
          end: Position(line: 0, character: 0),
        ),
        newText: 'import "$module"\n',
      ),
    ];
  }

  Map<String, dynamic> _createImportEdit(String uri, String module) {
    return {
      'changes': {
        uri: [
          {
            'range': {
              'start': {'line': 0, 'character': 0},
              'end': {'line': 0, 'character': 0},
            },
            'newText': 'import "$module"\n',
          },
        ],
      },
    };
  }
}

class DotContext {
  final String receiver;
  final bool isStaticOnly;
  DotContext(this.receiver, this.isStaticOnly);
}
