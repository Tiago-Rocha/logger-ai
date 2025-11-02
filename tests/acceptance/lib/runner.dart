import 'dart:async';

import 'dsl.dart';

class ScenarioResult {
  ScenarioResult({
    required this.scenario,
    required this.steps,
    this.skipped = false,
  });

  final Scenario scenario;
  final List<StepResult> steps;
  final bool skipped;

  bool get isSuccess => skipped || steps.every((step) => step.isSuccess);
}

class StepResult {
  StepResult({
    required this.step,
    this.error,
    this.stackTrace,
  });

  final ScenarioStep step;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isSuccess => error == null;
}

class ScenarioRunner {
  const ScenarioRunner(this.scenarios);

  final List<Scenario> scenarios;

  Future<List<ScenarioResult>> run() async {
    final results = <ScenarioResult>[];
    for (final scenario in scenarios) {
      results.add(await _runScenario(scenario));
    }
    return results;
  }

  Future<ScenarioResult> _runScenario(Scenario scenario) async {
    if (!scenario.isEnabled) {
      return ScenarioResult(
        scenario: scenario,
        steps: const [],
        skipped: true,
      );
    }
    final state = ScenarioState();
    final steps = <StepResult>[];
    for (final step in scenario.steps) {
      try {
        await step.handler(StepContext(state: state));
        steps.add(StepResult(step: step));
      } catch (error, stackTrace) {
        steps.add(
          StepResult(
            step: step,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        break;
      }
    }
    return ScenarioResult(scenario: scenario, steps: steps);
  }
}
