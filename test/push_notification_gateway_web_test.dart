@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/services/push_notification_gateway_web.dart';

@JS('Error')
extension type _NativeJavaScriptError._(JSObject _) implements JSObject {
  external factory _NativeJavaScriptError(JSString message);
}

@JS('DOMException')
extension type _NativeDomException._(JSObject _) implements JSObject {
  external factory _NativeDomException(JSString message, JSString name);
}

void main() {
  test('native JavaScript Error is classified without reading its message', () {
    final info = classifyWebPushUnsubscribeError(
      _NativeJavaScriptError('private-message'.toJS),
    );

    expect(info.name, 'Other');
    expect(info.errorClass, PushUnsubscribeErrorClass.error);
  });

  test('native DOMException name is allowlisted at trace emission', () {
    final info = classifyWebPushUnsubscribeError(
      _NativeDomException('private-message'.toJS, 'AbortError'.toJS),
    );

    expect(info.errorClass, PushUnsubscribeErrorClass.domException);
    expect(
      PushRecoveryTraceState.unsubscribeErrorName(info.name),
      'UNSUBSCRIBE_ERROR_NAME: AbortError',
    );
  });

  test('non-error JavaScript object is classified as Other', () {
    final info = classifyWebPushUnsubscribeError(JSObject());

    expect(info.name, 'Other');
    expect(info.errorClass, PushUnsubscribeErrorClass.other);
  });

  test('local subscription exception traces DOMException Error and Other', () {
    final traces = <String>[];
    final errors = <Object>[
      _NativeDomException('private-message'.toJS, 'AbortError'.toJS),
      _NativeJavaScriptError('private-message'.toJS),
      JSObject(),
    ];

    for (final error in errors) {
      traceLocalSubscriptionException(
        error: error,
        classifyError: (error) =>
            classifyWebPushUnsubscribeError(error).errorClass,
        trace: traces.add,
      );
    }

    expect(traces, [
      LocalSubscriptionTraceState.exceptionClass(
        PushUnsubscribeErrorClass.domException,
      ),
      LocalSubscriptionTraceState.exceptionClass(
        PushUnsubscribeErrorClass.error,
      ),
      LocalSubscriptionTraceState.exceptionClass(
        PushUnsubscribeErrorClass.other,
      ),
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });
}
