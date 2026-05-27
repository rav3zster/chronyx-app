import 'package:flutter/material.dart';

/// A single slice in the time-allocation breakdown.
class AllocationSlice {
  const AllocationSlice({
    required this.label,
    required this.minutes,
    required this.color,
    this.emoji,
  });

  final String label;
  final int minutes;
  final Color color;
  final String? emoji;
}

/// Aggregated allocation of how the user spent their time over a window.
class TimeAllocation {
  const TimeAllocation({
    required this.slices,
    required this.totalMinutes,
    required this.windowDays,
  });

  final List<AllocationSlice> slices;
  final int totalMinutes;
  final int windowDays;

  /// Sliced sorted by minutes descending.
  List<AllocationSlice> get sorted =>
      [...slices]..sort((a, b) => b.minutes.compareTo(a.minutes));

  /// Returns percentage (0.0–1.0) for the given slice.
  double percentageOf(AllocationSlice slice) {
    if (totalMinutes == 0) return 0;
    return slice.minutes / totalMinutes;
  }
}
