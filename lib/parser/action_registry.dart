import 'package:velvet_cmp/parser/ast_classes.dart';

class ActionParameter {
  final String name;
  final String syntaxType; // e.g., 'string', 'block', 'expression'

  ActionParameter(this.name, this.syntaxType);
}

class ActionDefinition {
  final String name;
  final List<ActionParameter> parameters;
  final List<Node> body;

  ActionDefinition(this.name, this.parameters, this.body);
}

class ActionRegistry {
  static final ActionRegistry _instance = ActionRegistry._internal();
  factory ActionRegistry() => _instance;
  ActionRegistry._internal();

  final Map<String, ActionDefinition> actions = {};

  void register(ActionDefinition action) {
    const supportedSyntaxTypes = {
      'string',
      'number',
      'boolean',
      'identifier',
      'keyword',
      'expression',
      'statement',
      'block',
      'type',
      'parameters',
    };
    for (final parameter in action.parameters) {
      if (!supportedSyntaxTypes.contains(parameter.syntaxType)) {
        throw ArgumentError(
          'Unsupported action parameter type: ${parameter.syntaxType}',
        );
      }
    }
    actions[action.name] = action;
  }

  void clear() => actions.clear();

  ActionDefinition? get(String name) {
    return actions[name];
  }
}
