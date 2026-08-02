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

  static String date(DateTime value) {
    return '${_weekdays[value.weekday - 1]} ${value.day} '
        '${_months[value.month - 1]} ${value.year}';
  }

  static String time(DateTime value) => timeFromParts(value.hour, value.minute);

  static String timeFromParts(int hour, int minute) {
    return '${_two(hour)}:${_two(minute)}';
  }

  static String timeRange(DateTime start, DateTime end) {
    return '${time(start)} — ${time(end)}';
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
