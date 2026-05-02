import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsSummary> fetchSummary();
}
