import 'package:flutter/foundation.dart';

/// Adapte un [ValueListenable] en stream rejouant immédiatement sa valeur.
///
/// Chaque abonnement possède son listener afin qu'un même flux contextualisé
/// puisse être démonté puis réécouté lors d'un changement de perspective.
Stream<T> watchValueListenable<T>(ValueListenable<T> source) =>
    Stream<T>.multi((controller) {
      void emit() => controller.add(source.value);

      try {
        controller.add(source.value);
        source.addListener(emit);
      } on FlutterError {
        // A late subscription can race with disposal of the owning scope while
        // an outer switchLatest is cancelling. The source is no longer usable,
        // so this subscription has no value to expose and closes cleanly.
        controller.close();
        return;
      }
      controller.onCancel = () => source.removeListener(emit);
    });
