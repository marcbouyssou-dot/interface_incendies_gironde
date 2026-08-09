import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/v5_foundation.dart';

class V5SecondaryNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  const V5SecondaryNavigationBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
  });

  static const double toolbarHeight = 54;

  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Size get preferredSize {
    final textScaleFactor =
        WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    final extraHeight = ((textScaleFactor - 1).clamp(0, 2)) * 64;
    return Size.fromHeight(toolbarHeight + extraHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final canGoBack = showBack && Navigator.of(context).canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightSystemUiOverlayStyle,
      child: ColoredBox(
        color: colors.canvas,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: preferredSize.height,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: canGoBack ? V5BackButton(onPressed: onBack) : null,
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: actions.isEmpty
                      ? null
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class V5BackButton extends StatelessWidget {
  const V5BackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      button: true,
      label: 'Retour',
      child: CupertinoButton(
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        onPressed: onPressed ?? () => Navigator.maybePop(context),
        child: Icon(CupertinoIcons.back, size: 25, color: colors.textPrimary),
      ),
    );
  }
}
