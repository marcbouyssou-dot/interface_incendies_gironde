import 'package:flutter/material.dart';

/// Short, shared timings for interactions that should feel native on iPhone.
abstract final class NativeMotion {
  static const Duration tabTransition = Duration(milliseconds: 160);
  static const Duration detailsExpansion = Duration(milliseconds: 220);
  static const Duration detailsCollapse = Duration(milliseconds: 180);
  static const Duration stateTransition = Duration(milliseconds: 180);

  static const AnimationStyle bottomSheet = AnimationStyle(
    duration: Duration(milliseconds: 300),
    reverseDuration: Duration(milliseconds: 240),
  );
}

Future<T?> showNativeBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = true,
  Color? backgroundColor,
  Color? barrierColor,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    sheetAnimationStyle: reduceMotion
        ? const AnimationStyle(
            duration: Duration.zero,
            reverseDuration: Duration.zero,
          )
        : NativeMotion.bottomSheet,
  );
}

/// Keeps every tab mounted while applying a short cross-fade on selection.
class NativeTabView extends StatefulWidget {
  const NativeTabView({super.key, required this.index, required this.children})
    : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;

  @override
  State<NativeTabView> createState() => _NativeTabViewState();
}

class _NativeTabViewState extends State<NativeTabView> {
  int? _previousIndex;

  @override
  void didUpdateWidget(NativeTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _previousIndex = oldWidget.index;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return IndexedStack(
        index: widget.index,
        sizing: StackFit.expand,
        children: [
          for (
            var childIndex = 0;
            childIndex < widget.children.length;
            childIndex++
          )
            TickerMode(
              enabled: childIndex == widget.index,
              child: widget.children[childIndex],
            ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (
          var childIndex = 0;
          childIndex < widget.children.length;
          childIndex++
        )
          Positioned.fill(
            child: Offstage(
              offstage:
                  childIndex != widget.index && childIndex != _previousIndex,
              child: IgnorePointer(
                ignoring: childIndex != widget.index,
                child: ExcludeSemantics(
                  excluding: childIndex != widget.index,
                  child: AnimatedOpacity(
                    key: ValueKey('native-tab-$childIndex'),
                    opacity: childIndex == widget.index ? 1 : 0,
                    duration: NativeMotion.tabTransition,
                    curve: Curves.easeOutCubic,
                    onEnd: childIndex == widget.index
                        ? () {
                            if (_previousIndex == null || !mounted) return;
                            setState(() => _previousIndex = null);
                          }
                        : null,
                    child: TickerMode(
                      enabled: childIndex == widget.index,
                      child: widget.children[childIndex],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
