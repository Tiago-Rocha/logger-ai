import 'dart:io';

import 'package:logger_acceptance_harness/logger_acceptance_harness.dart';
import 'package:logger_acceptance_harness/scenarios.dart';

Future<void> main(List<String> args) async {
  final runner = ScenarioRunner(allScenarios);
  final results = await runner.run();

  for (final result in results) {
    _printScenarioHeading(result);
    for (final step in result.steps) {
      _printStepOutcome(step);
    }
    stdout.writeln();
  }

  final failed = results.where((r) => !r.isSuccess).toList();
  if (failed.isNotEmpty) {
    stderr.writeln('${failed.length} scenario(s) remain pending or failed.');
    exitCode = 1;
  }
}

void _printScenarioHeading(ScenarioResult result) {
  final status = result.skipped
      ? 'SKIP'
      : result.isSuccess
          ? 'PASS'
          : 'FAIL';
  stdout.writeln('[$status] ${result.scenario.name}');
}

void _printStepOutcome(StepResult result) {
  final status = result.isSuccess ? '  ✔' : '  ✖';
  stdout.writeln('$status ${result.step.keyword} ${result.step.description}');
  if (!result.isSuccess) {
    stdout.writeln('      ${result.error}');
  }
}
