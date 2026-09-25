const _accentTransliterations = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

final _nonAlphanumericRun = RegExp('[^a-z0-9]+');
final _leadingOrTrailingDashes = RegExp(r'^-+|-+$');

/// Turns a location name (optionally prefixed, e.g. with a territorial
/// group) into a deterministic, URL/Firestore-safe slug: lowercase
/// ASCII letters, digits and single hyphens only. Accented Latin
/// characters are transliterated rather than dropped; every other
/// character (spaces, apostrophes, slashes, backslashes, punctuation)
/// collapses to a single hyphen, and the result never starts or ends
/// with one.
String locationSlug(String input) {
  var normalized = input.toLowerCase();
  for (final entry in _accentTransliterations.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized
      .replaceAll(_nonAlphanumericRun, '-')
      .replaceAll(_leadingOrTrailingDashes, '');
}
