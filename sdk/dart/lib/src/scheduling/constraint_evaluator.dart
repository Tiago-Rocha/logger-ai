import 'upload_schedule.dart';

/// Determines whether the current device state satisfies the requested
/// [UploadConstraints].
abstract class UploadConditionEvaluator {
  bool canRun(UploadConstraints constraints);
}

/// Default evaluator that permits every run.
class AllowAllConstraintEvaluator implements UploadConditionEvaluator {
  const AllowAllConstraintEvaluator();

  @override
  bool canRun(UploadConstraints constraints) => true;
}
