import 'dart:async';
import 'dart:js_interop';

@JS('window.open')
external JSAny? _openWindow(JSString url, JSString target);

Future<bool> openExternalUrl(Uri uri) async {
  final target = uri.scheme == 'tel' ? '_self' : '_blank';
  _openWindow(uri.toString().toJS, target.toJS);
  return true;
}
