import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class CreateEngagementErrorDetails {
  const CreateEngagementErrorDetails({
    required this.summary,
    required this.boxedStack,
  });

  final String summary;
  final String? boxedStack;
}

CreateEngagementErrorDetails unpackCreateEngagementError(
  Object error,
  StackTrace stackTrace,
) {
  JSAny? boxedError;
  JSAny? boxedStack;
  JSAny? code;
  JSAny? message;

  try {
    final jsError = error as JSObject;
    boxedError = _property(jsError, 'error');
    boxedStack = _property(jsError, 'stack');
    var firebaseError = jsError;
    if (boxedError != null) {
      try {
        firebaseError = boxedError as JSObject;
      } catch (_) {
        // A primitive boxed value has no Firebase properties to inspect.
      }
    }
    code = _property(firebaseError, 'code');
    message = _property(firebaseError, 'message');
  } catch (_) {
    // A native Dart exception is formatted by the common fallback below.
  }

  return CreateEngagementErrorDetails(
    summary:
        'CREATE_ENGAGEMENT_ERROR '
        'type=${error.runtimeType} '
        'boxedError=${_value(boxedError, fallback: error.toString())} '
        'code=${_value(code)} '
        'message=${_value(message)}',
    boxedStack: boxedStack == null ? null : _value(boxedStack),
  );
}

JSAny? _property(JSObject object, String name) {
  try {
    return object.getProperty<JSAny?>(name.toJS);
  } catch (_) {
    return null;
  }
}

String _value(JSAny? value, {String fallback = 'unavailable'}) {
  if (value == null) return fallback;
  try {
    return value.dartify()?.toString() ?? fallback;
  } catch (_) {
    return value.toString();
  }
}
