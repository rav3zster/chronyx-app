import 'package:flutter_test/flutter_test.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

void main() {
  test('TimeEntry duration is computed from started and ended times', () {
    final startedAt = DateTime.utc(2026, 1, 1, 10, 0, 0);
    final endedAt = DateTime.utc(2026, 1, 1, 11, 30, 0);

    final entry = TimeEntry(
      id: 'entry-1',
      taskName: 'Deep Work',
      startedAt: startedAt,
      endedAt: endedAt,
    );

    expect(entry.duration, const Duration(hours: 1, minutes: 30));
    expect(entry.isActive, isFalse);
  });
}
