import 'package:reliable_periodic_timer_example/safe_interval_timer.dart';
import 'package:test/test.dart';

void main() {
  group('Safe interval timer', () {
    test('optimistic approach should be unreliable', () async {
      var safeIntervalTimer = SafeIntervalTimer();

      safeIntervalTimer.optimisticApproach();

      await Future.delayed(const Duration(seconds: 7));

      expect(safeIntervalTimer.inAccurateTicks, isNonZero);
    });

    test('optimistic isolate approach should be unreliable', () async {
      var safeIntervalTimer = SafeIntervalTimer();

      safeIntervalTimer.optimisticIsolateApproach();

      await Future.delayed(const Duration(seconds: 7));

      expect(safeIntervalTimer.inAccurateTicks, isNonZero);
    });

    test('pessimistic approach should be reliable', () async {
      var safeIntervalTimer = SafeIntervalTimer();

      safeIntervalTimer.pessimisticApproach();

      await Future.delayed(const Duration(seconds: 7));

      expect(safeIntervalTimer.inAccurateTicks, isZero);
    });

    test('pessimistic isolate approach should be reliable', () async {
      var safeIntervalTimer = SafeIntervalTimer();

      safeIntervalTimer.pessimisticApproach();

      await Future.delayed(const Duration(seconds: 7));

      expect(safeIntervalTimer.inAccurateTicks, isZero);
    });
  });
}
