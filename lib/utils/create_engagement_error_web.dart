import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Reflect.ownKeys')
external JSArray<JSAny?> _reflectOwnKeys(JSObject target);

class CreateEngagementErrorDetails {
  const CreateEngagementErrorDetails({
    required this.summary,
    required this.boxedStack,
    required this.diagnostics,
  });

  final String summary;
  final String? boxedStack;
  final List<String> diagnostics;
}

CreateEngagementErrorDetails unpackCreateEngagementError(
  Object error,
  StackTrace stackTrace,
) {
  JSAny? boxedError;
  JSAny? boxedStack;
  JSAny? code;
  JSAny? message;
  final diagnostics = <String>[];

  try {
    final jsError = error as JSObject;
    diagnostics.addAll(_inspectObject('outer', jsError));
    boxedError = _property(jsError, 'error');
    boxedStack = _property(jsError, 'stack');
    var firebaseError = jsError;
    if (boxedError != null) {
      try {
        firebaseError = boxedError as JSObject;
        diagnostics.addAll(_inspectObject('inner.error', firebaseError));
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
    diagnostics: diagnostics,
  );
}

List<String> _inspectObject(String label, JSObject object) {
  final keys = <String>[];
  try {
    keys.addAll(_reflectOwnKeys(object).toDart.map(_value));
  } catch (_) {
    keys.add('unavailable');
  }
  final diagnostics = <String>['$label.ownKeys=${keys.join(',')}'];
  for (final property in const ['name', 'code', 'message', 'stack']) {
    diagnostics.add('$label.$property=${_value(_property(object, property))}');
  }
  diagnostics.add('$label.toString=${_callToString(object)}');
  return diagnostics;
}

JSAny? _property(JSObject object, String name) {
  try {
    return object.getProperty<JSAny?>(name.toJS);
  } catch (_) {
    return null;
  }
}

String _callToString(JSObject object) {
  try {
    return _value(object.callMethod<JSAny?>('toString'.toJS));
  } catch (_) {
    return 'unavailable';
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
