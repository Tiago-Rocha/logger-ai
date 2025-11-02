# Acceptance DSL Harness

This directory hosts the custom Given/When/Then harness that exercises the
Flutter Logger SDK end-to-end. Scenarios are defined in a plain-text DSL and
executed via `dart run tests/acceptance/main.dart`. Initially the scenarios are
expected to fail until their corresponding implementation work is completed.
