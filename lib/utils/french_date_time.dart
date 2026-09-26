abstract final class FrenchDateTime {
  static const _weekdays = <String>[
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  static const _months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _weekdaysShort = <String>[
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ];

  static const _monthsShort = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  static String date(DateTime value) {
    return '${_weekdays[value.weekday - 1]} ${value.day} '
        '${_months[value.month - 1]} ${value.year}';
  }

  static String time(DateTime value) => timeFromParts(value.hour, value.minute);

  static String timeFromParts(int hour, int minute) {
    return '${_two(hour)}:${_two(minute)}';
  }

  /// Clock range of a slot. The start date is shown separately by [date];
  /// when the slot ends on another calendar day, the end date is spelled out
  /// so a multi-day slot is never read as a same-day one.
  static String timeRange(DateTime start, DateTime end) {
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) return '${time(start)} — ${time(end)}';
    final year = end.year == start.year ? '' : ' ${end.year}';
    return '${time(start)} — ${_weekdaysShort[end.weekday - 1]} ${end.day} '
        '${_monthsShort[end.month - 1]}$year, ${time(end)}';
  }

  static String relativeDate(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final dateOnly = DateTime(value.year, value.month, value.day);
    final today = DateTime(reference.year, reference.month, reference.day);
    final difference = dateOnly.difference(today).inDays;
    return switch (difference) {
      -1 => 'Hier',
      0 => 'Aujourd’hui',
      1 => 'Demain',
      _ => date(value),
    };
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
