import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

const _touchDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

Set<Factory<OneSequenceGestureRecognizer>> operationalMapGestureRecognizers() {
  return <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(
      () => EagerGestureRecognizer(supportedDevices: _touchDevices),
    ),
  };
}

class OperationalMapGestureBoundary extends StatelessWidget {
  const OperationalMapGestureBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              () => EagerGestureRecognizer(supportedDevices: _touchDevices),
              (_) {},
            ),
      },
      child: child,
    );
  }
}
