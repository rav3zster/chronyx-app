enum AIInsightType { info, warning, suggestion }

class AIInsight {
  const AIInsight({
    required this.id,
    required this.message,
    required this.type,
    this.meta,
  });

  final String id;
  final String message;
  final AIInsightType type;
  final Map<String, dynamic>? meta;
}
