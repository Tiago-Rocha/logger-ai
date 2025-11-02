import 'package:meta/meta.dart';

/// Declarative description of how often uploads should run and under what
/// constraints.
@immutable
class UploadSchedule {
  const UploadSchedule({
    required this.frequency,
    this.constraints = const UploadConstraints(),
  });

  /// Interval between upload attempts.
  final Duration frequency;

  /// Device conditions that must be met before an upload executes.
  final UploadConstraints constraints;

  /// Convenience factory for periodic schedules.
  factory UploadSchedule.periodic({
    required Duration frequency,
    UploadConstraints constraints = const UploadConstraints(),
  }) {
    return UploadSchedule(frequency: frequency, constraints: constraints);
  }
}

/// Simple connectivity and power constraints requested by the host app.
@immutable
class UploadConstraints {
  const UploadConstraints({
    this.wifiOnly = false,
    this.requiresCharging = false,
  });

  /// Whether uploads should run only when on Wi-Fi.
  final bool wifiOnly;

  /// Whether uploads should run only when the device is charging.
  final bool requiresCharging;
}
