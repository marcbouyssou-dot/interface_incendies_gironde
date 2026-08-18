import 'package:flutter/foundation.dart';

void debugLogRuntimeStreamError({
  required String surface,
  required String source,
  required Object? error,
  StackTrace? stackTrace,
}) {
  assert(() {
    debugPrint('$surface [$source] : $error');
    if (stackTrace != null) {
      debugPrintStack(label: '$surface [$source]', stackTrace: stackTrace);
    }
    return true;
  }());
}
