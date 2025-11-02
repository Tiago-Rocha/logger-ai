typedef StepHandler = Future<void> Function(StepContext context);

class StepContext {
  StepContext({required this.state});

  final ScenarioState state;

  T read<T>(String key) => state.read<T>(key);
  T? maybeRead<T>(String key) => state.maybeRead<T>(key);
  void write(String key, Object? value) => state.write(key, value);
}

class ScenarioState {
  final Map<String, Object?> _values = {};

  T read<T>(String key) {
    final value = _values[key];
    if (value is! T) {
      throw StateError(
          'Expected `$key` to be of type $T but was ${value.runtimeType}.');
    }
    return value;
  }

  void write(String key, Object? value) {
    _values[key] = value;
  }

  T? maybeRead<T>(String key) {
    if (!_values.containsKey(key)) {
      return null;
    }
    final value = _values[key];
    if (value is! T) {
      throw StateError(
          'Expected `$key` to be of type $T but was ${value.runtimeType}.');
    }
    return value;
  }

  bool contains(String key) => _values.containsKey(key);
}

class Scenario {
  Scenario({
    required this.name,
    required this.steps,
    required this.isEnabled,
  });

  final String name;
  final List<ScenarioStep> steps;
  final bool isEnabled;
}

class ScenarioStep {
  ScenarioStep({
    required this.keyword,
    required this.description,
    required this.handler,
  });

  final String keyword;
  final String description;
  final StepHandler handler;
}

Scenario scenario(
  String name,
  void Function(ScenarioBuilder builder) build, {
  bool enabled = true,
}) {
  final builderInstance = ScenarioBuilder._(name);
  build(builderInstance);
  return Scenario(
    name: name,
    steps: List.unmodifiable(builderInstance._steps),
    isEnabled: enabled,
  );
}

class ScenarioBuilder {
  ScenarioBuilder._(this._name);

  final String _name;
  final List<ScenarioStep> _steps = [];

  void given(String description, StepHandler handler) {
    _addStep('Given', description, handler);
  }

  void when(String description, StepHandler handler) {
    _addStep('When', description, handler);
  }

  void then(String description, StepHandler handler) {
    _addStep('Then', description, handler);
  }

  void and(String description, StepHandler handler) {
    if (_steps.isEmpty) {
      throw StateError('`and` cannot be the first step in scenario `$_name`.');
    }
    _addStep('And', description, handler);
  }

  void _addStep(String keyword, String description, StepHandler handler) {
    _steps.add(
      ScenarioStep(
        keyword: keyword,
        description: description,
        handler: handler,
      ),
    );
  }
}

class PendingStep implements Exception {
  const PendingStep([this.message = 'Pending implementation']);

  final String message;

  @override
  String toString() => message;
}
