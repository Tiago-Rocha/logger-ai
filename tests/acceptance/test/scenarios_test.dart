import 'package:logger_acceptance_harness/logger_acceptance_harness.dart';
import 'package:logger_acceptance_harness/scenarios.dart';
import 'package:test/test.dart';

void main() {
  for (final scenario in allScenarios) {
    test(
      scenario.name,
      () async {
        if (!scenario.isEnabled) {
          return;
        }
        final runner = ScenarioRunner([scenario]);
        final result = await runner.run();
        final failures =
            result.single.steps.where((step) => !step.isSuccess).toList();
        if (failures.isNotEmpty) {
          final failure = failures.first;
          fail(
            '${failure.step.keyword} ${failure.step.description} => ${failure.error}',
          );
        }
      },
      skip: scenario.isEnabled ? false : 'Scenario disabled',
    );
  }
}
