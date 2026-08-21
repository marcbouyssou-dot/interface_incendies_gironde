import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapte un [ValueListenable] en stream rejouant immédiatement sa valeur.
Stream<T> watchValueListenable<T>(ValueListenable<T> source) {
  late StreamController<T> controller;

  void emit() {
    if (!controller.isClosed) controller.add(source.value);
  }

  controller = StreamController<T>(
    onListen: () {
      controller.add(source.value);
      source.addListener(emit);
    },
    onCancel: () => source.removeListener(emit),
  );
  return controller.stream;
}
