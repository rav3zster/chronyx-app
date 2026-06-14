import 'package:chronyx/features/todos/domain/entities/todo.dart';

class ParsedTodoNli {
  final String title;
  final DateTime? dueDate;
  final String? recurrence;
  final TodoPriority priority;
  final DateTime? reminderTime;
  final List<String> tags;

  ParsedTodoNli({
    required this.title,
    this.dueDate,
    this.recurrence,
    this.priority = TodoPriority.medium,
    this.reminderTime,
    this.tags = const [],
  });
}

class TodoNliParser {
  static ParsedTodoNli parse(String input) {
    String title = input;
    DateTime? dueDate;
    String? recurrence;
    TodoPriority priority = TodoPriority.medium;
    DateTime? reminderTime;
    final List<String> tags = [];

    final now = DateTime.now();

    // 1. Parse Tags (e.g. #flutter, #work)
    final tagRegex = RegExp(r'#([a-zA-Z0-9_\-]+)');
    final tagMatches = tagRegex.allMatches(title);
    for (final match in tagMatches) {
      final tag = match.group(1);
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag.toLowerCase());
      }
    }
    title = title.replaceAll(tagRegex, '');

    // 2. Parse Priority
    // Look for "!!!", "!!", "!", or "priority critical/high/medium/low", or "p:critical/high/medium/low"
    final priorityRegex = RegExp(
      r'\b(priority|p)[:\s]+(critical|high|medium|low)\b|(!{1,3})',
      caseSensitive: false,
    );
    final priorityMatch = priorityRegex.firstMatch(title);
    if (priorityMatch != null) {
      final text = priorityMatch.group(0);
      if (text == '!!!') {
        priority = TodoPriority.critical;
      } else if (text == '!!') {
        priority = TodoPriority.high;
      } else if (text == '!') {
        priority = TodoPriority.medium;
      } else {
        final val = (priorityMatch.group(2) ?? '').toLowerCase();
        if (val == 'critical') priority = TodoPriority.critical;
        if (val == 'high') priority = TodoPriority.high;
        if (val == 'medium') priority = TodoPriority.medium;
        if (val == 'low') priority = TodoPriority.low;
      }
      title = title.replaceAll(priorityRegex, '');
    }

    // 3. Parse Recurrence
    // Look for "every day", "every week", "every month", "every monday", etc., or "daily", "weekly", "monthly"
    final recurrenceRegex = RegExp(
      r'\b(every|each)\s+(day|week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b|\b(daily|weekly|monthly)\b',
      caseSensitive: false,
    );
    final recurrenceMatch = recurrenceRegex.firstMatch(title);
    if (recurrenceMatch != null) {
      final matchStr = recurrenceMatch.group(0)!.toLowerCase();
      if (matchStr.contains('week') || matchStr.contains('weekly') || 
          matchStr.contains('monday') || matchStr.contains('tuesday') || 
          matchStr.contains('wednesday') || matchStr.contains('thursday') || 
          matchStr.contains('friday') || matchStr.contains('saturday') || 
          matchStr.contains('sunday')) {
        recurrence = 'weekly';
      } else if (matchStr.contains('month') || matchStr.contains('monthly')) {
        recurrence = 'monthly';
      } else {
        recurrence = 'daily';
      }
      title = title.replaceAll(recurrenceRegex, '');
    }

    // 4. Parse Date (Today, Tomorrow, Weekdays, Specific dates)
    // Today / Tomorrow
    final relativeDateRegex = RegExp(r'\b(today|tomorrow)\b', caseSensitive: false);
    final relativeDateMatch = relativeDateRegex.firstMatch(title);
    if (relativeDateMatch != null) {
      final keyword = relativeDateMatch.group(0)!.toLowerCase();
      if (keyword == 'today') {
        dueDate = DateTime(now.year, now.month, now.day);
      } else if (keyword == 'tomorrow') {
        dueDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      }
      title = title.replaceAll(relativeDateRegex, '');
    }

    // Weekdays
    if (dueDate == null) {
      final weekdayRegex = RegExp(
        r'\b(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      );
      final weekdayMatch = weekdayRegex.firstMatch(title);
      if (weekdayMatch != null) {
        final weekdayName = weekdayMatch.group(2)!.toLowerCase();
        final targetWeekday = switch (weekdayName) {
          'monday' => DateTime.monday,
          'tuesday' => DateTime.tuesday,
          'wednesday' => DateTime.wednesday,
          'thursday' => DateTime.thursday,
          'friday' => DateTime.friday,
          'saturday' => DateTime.saturday,
          'sunday' => DateTime.sunday,
          _ => now.weekday,
        };
        int daysToAdd = targetWeekday - now.weekday;
        if (daysToAdd <= 0) daysToAdd += 7;
        dueDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
        title = title.replaceAll(weekdayRegex, '');
      }
    }

    // Specific Date: e.g. "June 25", "on June 25", "June 25th", "25 June", "25th of June"
    if (dueDate == null) {
      final monthsList = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
      final dateRegex = RegExp(
        r'\b(on\s+)?([0-9]{1,2})(st|nd|rd|th)?\s+(of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b|\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+([0-9]{1,2})(st|nd|rd|th)?\b',
        caseSensitive: false,
      );
      final dateMatch = dateRegex.firstMatch(title);
      if (dateMatch != null) {
        String? monthStr;
        int? dayVal;

        if (dateMatch.group(5) != null) {
          monthStr = dateMatch.group(5)!.toLowerCase();
          dayVal = int.tryParse(dateMatch.group(2) ?? '');
        } else if (dateMatch.group(6) != null) {
          monthStr = dateMatch.group(6)!.toLowerCase();
          dayVal = int.tryParse(dateMatch.group(7) ?? '');
        }

        if (monthStr != null && dayVal != null) {
          int monthVal = 1;
          for (int i = 0; i < monthsList.length; i++) {
            if (monthStr.startsWith(monthsList[i])) {
              monthVal = i + 1;
              break;
            }
          }
          int yearVal = now.year;
          if (monthVal < now.month || (monthVal == now.month && dayVal < now.day)) {
            yearVal++;
          }
          dueDate = DateTime(yearVal, monthVal, dayVal);
          title = title.replaceAll(dateRegex, '');
        }
      }
    }

    // 5. Parse Time (at 7 PM, 7:30 PM, 19:00, etc.)
    final timeRegex = RegExp(
      r'\b(at\s+)?([0-9]{1,2})(:([0-9]{2}))?\s*(am|pm)\b|\b(at\s+)?([0-9]{1,2}):([0-9]{2})\b',
      caseSensitive: false,
    );
    final timeMatch = timeRegex.firstMatch(title);
    if (timeMatch != null) {
      int hour = 0;
      int minute = 0;
      bool isPm = false;
      bool hasAmPm = false;

      if (timeMatch.group(5) != null) {
        hour = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
        minute = int.tryParse(timeMatch.group(4) ?? '') ?? 0;
        isPm = timeMatch.group(5)!.toLowerCase() == 'pm';
        hasAmPm = true;
      } else {
        hour = int.tryParse(timeMatch.group(8) ?? '') ?? 0;
        minute = int.tryParse(timeMatch.group(9) ?? '') ?? 0;
      }

      if (hasAmPm) {
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      }

      dueDate ??= DateTime(now.year, now.month, now.day);
      dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day, hour, minute);
      reminderTime = dueDate;
      title = title.replaceAll(timeRegex, '');
    }

    // Clean up title
    title = title
        .replaceAll(RegExp(r'\b(on|at|every|each)\b\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (title.isEmpty) {
      title = input;
    }

    return ParsedTodoNli(
      title: title,
      dueDate: dueDate,
      recurrence: recurrence,
      priority: priority,
      reminderTime: reminderTime,
      tags: tags,
    );
  }
}
