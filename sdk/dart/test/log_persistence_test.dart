import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('LogPersistence', () {
    test('placeholder', () {
      const persistence = LogPersistence();
      expect(persistence, isA<LogPersistence>());
    });
  });
}
