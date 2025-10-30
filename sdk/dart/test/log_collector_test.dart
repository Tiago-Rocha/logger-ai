import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('LogCollector', () {
    test('placeholder', () {
      const collector = LogCollector();
      expect(collector, isA<LogCollector>());
    });
  });
}
