class ChecklistItem {
  final int lineIndex;
  final String text;
  final bool isChecked;

  const ChecklistItem({
    required this.lineIndex,
    required this.text,
    required this.isChecked,
  });
}

class TodoChecklistParser {
  // Matches lines starting with [ ], [x], ☐, or ☑
  static final RegExp _checklistRegExp = RegExp(
    r'^\s*([\[\(]([ xX]?)[\]\)]|([☐☑]))\s*(.*)$',
  );

  static List<ChecklistItem> parse(String? notes) {
    if (notes == null || notes.isEmpty) return const [];
    final lines = notes.split('\n');
    final List<ChecklistItem> items = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _checklistRegExp.firstMatch(line);
      if (match != null) {
        final content = match.group(2);
        final unicodeChar = match.group(3);
        
        bool isChecked = false;
        if (content != null) {
          isChecked = content.toLowerCase() == 'x';
        } else if (unicodeChar != null) {
          isChecked = unicodeChar == '☑';
        }

        final text = match.group(4) ?? '';
        items.add(ChecklistItem(
          lineIndex: i,
          text: text.trim(),
          isChecked: isChecked,
        ));
      }
    }
    return items;
  }

  static String toggle(String notes, int lineIndex) {
    final lines = notes.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return notes;

    final line = lines[lineIndex];
    final match = _checklistRegExp.firstMatch(line);
    if (match != null) {
      final bracketMatch = match.group(2);
      final unicodeMatch = match.group(3);

      String newLine = line;
      if (bracketMatch != null) {
        final newBox = bracketMatch.toLowerCase() == 'x' ? '[ ]' : '[x]';
        newLine = line.replaceFirst(match.group(1)!, newBox);
      } else if (unicodeMatch != null) {
        final newChar = unicodeMatch == '☑' ? '☐' : '☑';
        newLine = line.replaceFirst(unicodeMatch, newChar);
      }
      lines[lineIndex] = newLine;
    }

    return lines.join('\n');
  }
}
