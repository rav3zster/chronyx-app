import 'package:chronyx/features/life_insights/domain/entities/insight_window.dart';
import 'package:chronyx/features/life_insights/domain/entities/greeting.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_report.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_snapshot.dart';

/// Repository for computing life insights from existing app data.
///
/// Aggregates time entries, projects, goals, and tasks. Pure read-only.
abstract class LifeInsightsRepository {
  /// Lightweight snapshot for the dashboard mini panel (7-day window).
  Future<LifeSnapshot> fetchSnapshot({int windowDays = 7});

  /// Full report for the Life Insights screen.
  Future<LifeReport> fetchReport({InsightWindow window = InsightWindow.week});

  /// Contextual dashboard greeting based on time of day + recent behavior.
  Future<Greeting> fetchGreeting({required String displayName});
}
