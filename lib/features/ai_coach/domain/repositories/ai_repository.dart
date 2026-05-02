import 'package:chronyx/features/ai_coach/domain/entities/ai_insight.dart';

abstract class AIRepository {
  Future<List<AIInsight>> generateInsights();
}
