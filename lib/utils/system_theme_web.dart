// ignore: deprecated_member_use
import 'dart:html' as html;

void activateLightApplicationChrome() {
  html.document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', '#F6F7F8');
  (html.document.querySelector('html') as html.HtmlElement?)
          ?.style
          .backgroundColor =
      '#F6F7F8';
  html.document.body?.style.backgroundColor = '#F6F7F8';
}
