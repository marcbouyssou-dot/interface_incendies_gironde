import 'dart:convert';
import 'dart:js_interop';

extension type _AnchorElement._(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
  external void remove();
}

@JS('document.createElement')
external _AnchorElement _createElement(JSString tagName);

Future<bool> exportCsvFile({
  required String fileName,
  required String contents,
}) async {
  final uri = Uri.dataFromString(
    contents,
    mimeType: 'text/csv',
    encoding: utf8,
  );
  final anchor = _createElement('a'.toJS)
    ..href = uri.toString().toJS
    ..download = fileName.toJS;
  anchor.click();
  anchor.remove();
  return true;
}
