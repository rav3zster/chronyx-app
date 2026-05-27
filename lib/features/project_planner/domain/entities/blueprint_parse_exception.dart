/// Severity level for parse issues.
enum ParseIssueSeverity {
  /// Non-blocking issue — data was recovered or defaulted.
  warning,

  /// Blocking issue — parsing cannot continue.
  error,
}

/// A single field-level issue encountered during parsing.
class ParseIssue {
  const ParseIssue({
    required this.severity,
    required this.field,
    required this.message,
  });

  final ParseIssueSeverity severity;
  final String field;
  final String message;

  @override
  String toString() => '[${severity.name.toUpperCase()}] $field: $message';
}

/// Exception thrown when blueprint parsing fails or encounters issues.
///
/// Supports:
/// - A user-friendly top-level [message]
/// - Field-level [issues] (warnings and errors)
/// - Distinction between blocking errors and recoverable warnings
class BlueprintParseException implements Exception {
  const BlueprintParseException({
    required this.message,
    this.issues = const [],
  });

  /// User-friendly error message.
  final String message;

  /// Detailed field-level issues found during parsing.
  final List<ParseIssue> issues;

  /// Whether any issue is blocking (error severity).
  bool get hasErrors =>
      issues.any((i) => i.severity == ParseIssueSeverity.error);

  /// Whether there are non-blocking warnings.
  bool get hasWarnings =>
      issues.any((i) => i.severity == ParseIssueSeverity.warning);

  /// Only the error-level issues.
  List<ParseIssue> get errors =>
      issues.where((i) => i.severity == ParseIssueSeverity.error).toList();

  /// Only the warning-level issues.
  List<ParseIssue> get warnings =>
      issues.where((i) => i.severity == ParseIssueSeverity.warning).toList();

  @override
  String toString() =>
      'BlueprintParseException: $message'
      '${issues.isNotEmpty ? '\n${issues.join('\n')}' : ''}';
}
