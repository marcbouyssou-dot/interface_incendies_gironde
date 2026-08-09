import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

enum V5ButtonTone { primary, secondary, tonal, destructive }

class V5Button extends StatelessWidget {
  const V5Button({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.tone = V5ButtonTone.primary,
    this.expanded = false,
    this.compact = false,
    this.loading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final V5ButtonTone tone;
  final bool expanded;
  final bool compact;
  final bool loading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final enabled = onPressed != null && !loading;
    final resolvedBackground =
        backgroundColor ??
        switch (tone) {
          V5ButtonTone.primary => colors.accent,
          V5ButtonTone.secondary => colors.surfaceElevated,
          V5ButtonTone.tonal => colors.surfaceMuted,
          V5ButtonTone.destructive => colors.danger,
        };
    final resolvedForeground =
        foregroundColor ??
        switch (tone) {
          V5ButtonTone.primary => colors.onAccent,
          V5ButtonTone.secondary => colors.textPrimary,
          V5ButtonTone.tonal => colors.textPrimary,
          V5ButtonTone.destructive => Colors.white,
        };
    final effectiveBackground = enabled
        ? resolvedBackground
        : colors.disabledBackground;
    final effectiveForeground = enabled
        ? resolvedForeground
        : colors.disabledForeground;
    final border = !enabled
        ? Border.all(color: colors.outline)
        : tone == V5ButtonTone.secondary
        ? Border.all(color: colors.outline)
        : null;
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: loading
          ? Row(
              key: const ValueKey('loading'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                V5ActivityIndicator(
                  color: effectiveForeground,
                  size: compact ? 16 : 18,
                ),
                const SizedBox(width: V5Spacing.xs),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: effectiveForeground,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: compact ? 17 : 19),
                  const SizedBox(width: V5Spacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: effectiveForeground,
                    ),
                  ),
                ),
              ],
            ),
    );
    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: effectiveBackground,
        border: border,
        borderRadius: BorderRadius.circular(V5Radius.control),
      ),
      child: CupertinoButton(
        minimumSize: Size.square(compact ? 44 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? V5Spacing.sm : V5Spacing.md,
          vertical: compact ? V5Spacing.xs : V5Spacing.sm,
        ),
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class V5ActivityIndicator extends StatelessWidget {
  const V5ActivityIndicator({super.key, this.color, this.size = 20});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CupertinoActivityIndicator(
      radius: size / 2,
      color: color ?? context.v5Colors.textSecondary,
    ),
  );
}

class V5CheckboxTile extends StatelessWidget {
  const V5CheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.subtitle,
    this.enabled = true,
    this.dense = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final String? subtitle;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final interactive = enabled && onChanged != null;
    return Semantics(
      checked: value,
      enabled: interactive,
      button: true,
      label: label,
      child: CupertinoButton(
        minimumSize: const Size.square(44),
        padding: EdgeInsets.symmetric(vertical: dense ? 4 : 8),
        alignment: Alignment.centerLeft,
        onPressed: interactive ? () => onChanged?.call(!value) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? colors.accent : colors.surfaceElevated,
                border: Border.all(
                  color: value ? colors.accent : colors.outline,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: value
                  ? Icon(Icons.check_rounded, size: 17, color: colors.onAccent)
                  : null,
            ),
            const SizedBox(width: V5Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: interactive
                          ? colors.textPrimary
                          : colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: V5Spacing.xxs),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class V5SwitchTile extends StatelessWidget {
  const V5SwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: title,
      child: CupertinoButton(
        minimumSize: const Size(44, 52),
        padding: EdgeInsets.zero,
        onPressed: onChanged == null ? null : () => onChanged?.call(!value),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: V5Spacing.xxs),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: V5Spacing.md),
            CupertinoSwitch(
              value: value,
              activeTrackColor: activeColor ?? colors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class V5ChoiceChip extends StatelessWidget {
  const V5ChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? colors.warningContainer : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.pill),
          border: Border.all(
            color: selected ? colors.accent : colors.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: CupertinoButton(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: V5Spacing.sm,
            vertical: V5Spacing.xs,
          ),
          onPressed: onSelected == null
              ? null
              : () => onSelected?.call(!selected),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected || icon != null) ...[
                Icon(
                  selected ? Icons.check_rounded : icon,
                  color: colors.accent,
                  size: 17,
                ),
                const SizedBox(width: V5Spacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
