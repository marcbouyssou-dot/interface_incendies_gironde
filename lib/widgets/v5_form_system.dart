import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/v5_foundation.dart';
import 'native_interactions.dart';
import 'v5_controls.dart';

class V5TextField extends StatefulWidget {
  const V5TextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.supportingText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.onTapOutside,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.obscureText = false,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.scrollPadding = const EdgeInsets.all(20),
    this.autovalidateMode,
    this.isRequired = false,
    this.semanticLabel,
  }) : assert(controller == null || initialValue == null),
       assert(minLines > 0),
       assert(maxLines == null || maxLines >= minLines);

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? supportingText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool obscureText;
  final bool autofocus;
  final int minLines;
  final int? maxLines;
  final int? maxLength;
  final EdgeInsets scrollPadding;
  final AutovalidateMode? autovalidateMode;
  final bool isRequired;
  final String? semanticLabel;

  @override
  State<V5TextField> createState() => _V5TextFieldState();
}

class _V5TextFieldState extends State<V5TextField> {
  String? _validationError;

  String? _validate(String? value) {
    final error = widget.validator?.call(value);
    if (error != _validationError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && error != _validationError) {
          setState(() => _validationError = error);
        }
      });
    }
    return error;
  }

  String get _accessibilityLabel {
    final label = widget.semanticLabel ?? widget.label;
    final error = widget.errorText ?? _validationError;
    return [
      label,
      if (widget.isRequired) 'obligatoire',
      if (error != null && error.trim().isNotEmpty) 'Erreur : $error',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return _V5FieldLabel(
      label: widget.label,
      enabled: widget.enabled,
      excludeLabelSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          label: _accessibilityLabel,
          child: TextFormField(
            controller: widget.controller,
            initialValue: widget.initialValue,
            focusNode: widget.focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            validator: widget.validator == null ? null : _validate,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            onTap: widget.onTap,
            onTapOutside: widget.onTapOutside,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autocorrect: widget.autocorrect,
            enableSuggestions: widget.enableSuggestions,
            obscureText: widget.obscureText,
            autofocus: widget.autofocus,
            minLines: widget.obscureText ? 1 : widget.minLines,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            scrollPadding: widget.scrollPadding,
            autovalidateMode: widget.autovalidateMode,
            cursorColor: colors.accent,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
            decoration: _fieldDecoration(
              context,
              hint: widget.hint,
              supportingText: widget.supportingText,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              enabled: widget.enabled,
              multiline: widget.maxLines != 1,
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class V5SelectOption<T> {
  const V5SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
}

class V5SelectField<T> extends StatelessWidget {
  const V5SelectField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder = 'Sélectionner',
    this.sheetTitle,
    this.supportingText,
    this.enabled = true,
    this.validator,
    this.autovalidateMode,
    this.leading,
    this.focusNode,
  });

  final String label;
  final List<V5SelectOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String placeholder;
  final String? sheetTitle;
  final String? supportingText;
  final bool enabled;
  final FormFieldValidator<T>? validator;
  final AutovalidateMode? autovalidateMode;
  final Widget? leading;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: ValueKey(value),
      initialValue: value,
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (state) {
        final selected = _optionFor(state.value);
        final interactive = enabled && onChanged != null;
        return _V5PickerFormField(
          label: label,
          value: selected?.label,
          placeholder: placeholder,
          supportingText: supportingText,
          errorText: state.errorText,
          leading: leading,
          enabled: interactive,
          icon: Icons.unfold_more_rounded,
          semanticValue: selected?.label,
          focusNode: focusNode,
          onTap: !interactive
              ? null
              : () async {
                  final selection = await _showOptions(context, state.value);
                  if (selection == null) return;
                  state.didChange(selection);
                  onChanged?.call(selection);
                  final selectedOption = _optionFor(selection);
                  if (selectedOption != null && context.mounted) {
                    if (MediaQuery.supportsAnnounceOf(context)) {
                      SemanticsService.sendAnnouncement(
                        View.of(context),
                        '${selectedOption.label}, sélectionné',
                        Directionality.of(context),
                      );
                    }
                  }
                },
        );
      },
    );
  }

  V5SelectOption<T>? _optionFor(T? selectedValue) {
    for (final option in options) {
      if (option.value == selectedValue) return option;
    }
    return null;
  }

  Future<T?> _showOptions(BuildContext context, T? selectedValue) {
    final colors = context.v5Colors;
    return showNativeBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surfaceElevated,
      builder: (sheetContext) => _V5SelectionSheet<T>(
        title: sheetTitle ?? label,
        options: options,
        selectedValue: selectedValue,
      ),
    );
  }
}

class V5DateField extends StatelessWidget {
  const V5DateField({
    super.key,
    required this.label,
    required this.onChanged,
    this.value,
    this.placeholder = 'Choisir une date',
    this.sheetTitle,
    this.supportingText,
    this.firstDate,
    this.lastDate,
    this.formatter,
    this.enabled = true,
    this.validator,
    this.autovalidateMode,
    this.focusNode,
  });

  final String label;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? value;
  final String placeholder;
  final String? sheetTitle;
  final String? supportingText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String Function(BuildContext context, DateTime value)? formatter;
  final bool enabled;
  final FormFieldValidator<DateTime>? validator;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      key: ValueKey(value),
      initialValue: value,
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (state) {
        final interactive = enabled && onChanged != null;
        return _V5PickerFormField(
          label: label,
          value: state.value == null
              ? null
              : (formatter ?? _defaultDateFormatter)(context, state.value!),
          placeholder: placeholder,
          supportingText: supportingText,
          errorText: state.errorText,
          enabled: interactive,
          icon: Icons.calendar_today_outlined,
          semanticValue: state.value == null
              ? null
              : _semanticDate(state.value!),
          focusNode: focusNode,
          onTap: !interactive
              ? null
              : () async {
                  final selection = await _showPicker(context, state.value);
                  if (selection == null) return;
                  state.didChange(selection);
                  onChanged?.call(selection);
                },
        );
      },
    );
  }

  Future<DateTime?> _showPicker(BuildContext context, DateTime? selectedValue) {
    final now = DateTime.now();
    final minimum = firstDate ?? DateTime(now.year - 100);
    final maximum = lastDate ?? DateTime(now.year + 10, 12, 31);
    assert(!maximum.isBefore(minimum));
    var pending = _clampDate(selectedValue ?? now, minimum, maximum);
    final colors = context.v5Colors;
    return showNativeBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surfaceElevated,
      builder: (sheetContext) => _V5PickerSheet(
        title: sheetTitle ?? label,
        onConfirm: () => Navigator.of(sheetContext).pop(pending),
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: pending,
            minimumDate: minimum,
            maximumDate: maximum,
            onDateTimeChanged: (value) => pending = value,
          ),
        ),
      ),
    );
  }

  static String _defaultDateFormatter(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value);

  static String _semanticDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  static DateTime _clampDate(
    DateTime value,
    DateTime minimum,
    DateTime maximum,
  ) {
    if (value.isBefore(minimum)) return minimum;
    if (value.isAfter(maximum)) return maximum;
    return value;
  }
}

class V5TimeField extends StatelessWidget {
  const V5TimeField({
    super.key,
    required this.label,
    required this.onChanged,
    this.value,
    this.placeholder = 'Choisir une heure',
    this.sheetTitle,
    this.supportingText,
    this.minuteInterval = 1,
    this.use24HourFormat,
    this.pickerInitialValue,
    this.enabled = true,
    this.validator,
    this.autovalidateMode,
    this.focusNode,
  }) : assert(minuteInterval > 0 && 60 % minuteInterval == 0);

  final String label;
  final ValueChanged<TimeOfDay?>? onChanged;
  final TimeOfDay? value;
  final String placeholder;
  final String? sheetTitle;
  final String? supportingText;
  final int minuteInterval;
  final bool? use24HourFormat;
  final TimeOfDay? pickerInitialValue;
  final bool enabled;
  final FormFieldValidator<TimeOfDay>? validator;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FormField<TimeOfDay>(
      key: ValueKey(value),
      initialValue: value,
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (state) {
        final interactive = enabled && onChanged != null;
        return _V5PickerFormField(
          label: label,
          value: state.value == null
              ? null
              : MaterialLocalizations.of(
                  context,
                ).formatTimeOfDay(state.value!, alwaysUse24HourFormat: true),
          placeholder: placeholder,
          supportingText: supportingText,
          errorText: state.errorText,
          enabled: interactive,
          icon: Icons.schedule_outlined,
          semanticValue: state.value?.format(context),
          focusNode: focusNode,
          onTap: !interactive
              ? null
              : () async {
                  final selection = await _showPicker(context, state.value);
                  if (selection == null) return;
                  state.didChange(selection);
                  onChanged?.call(selection);
                },
        );
      },
    );
  }

  Future<TimeOfDay?> _showPicker(
    BuildContext context,
    TimeOfDay? selectedValue,
  ) {
    final rawInitial = selectedValue ?? pickerInitialValue ?? TimeOfDay.now();
    final initial = TimeOfDay(
      hour: rawInitial.hour,
      minute: rawInitial.minute - (rawInitial.minute % minuteInterval),
    );
    var pending = initial;
    final colors = context.v5Colors;
    final use24Hour =
        use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
    return showNativeBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surfaceElevated,
      builder: (sheetContext) => _V5PickerSheet(
        title: sheetTitle ?? label,
        onConfirm: () => Navigator.of(sheetContext).pop(pending),
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: use24Hour,
            minuteInterval: minuteInterval,
            initialDateTime: DateTime(2000, 1, 1, initial.hour, initial.minute),
            onDateTimeChanged: (value) =>
                pending = TimeOfDay(hour: value.hour, minute: value.minute),
          ),
        ),
      ),
    );
  }
}

class V5Section extends StatelessWidget {
  const V5Section({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.all(V5Spacing.lg),
    this.elevated = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      container: true,
      label: title,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.card),
          border: Border.all(color: colors.outline.withValues(alpha: 0.72)),
          boxShadow: elevated ? V5Elevation.level1(colors) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: colors.accent, size: 20),
                    child: leading!,
                  ),
                  const SizedBox(width: V5Spacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle case final text?
                          when text.trim().isNotEmpty) ...[
                        const SizedBox(height: V5Spacing.xxs),
                        Text(
                          text,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: V5Spacing.sm),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: V5Spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class V5EmptyState extends StatelessWidget {
  const V5EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return SafeArea(
      minimum: const EdgeInsets.all(V5Spacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Semantics(
            container: true,
            label: '$title. $message',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(V5Radius.section),
                    ),
                    child: Icon(icon, color: colors.textSecondary, size: 24),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: V5Spacing.lg),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class V5LoadingState extends StatelessWidget {
  const V5LoadingState({
    super.key,
    this.label = 'Chargement…',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return SafeArea(
      minimum: EdgeInsets.all(compact ? V5Spacing.md : V5Spacing.xl),
      child: Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: label,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(
                  animating: !MediaQuery.disableAnimationsOf(context),
                  radius: compact ? 10 : 13,
                  color: colors.accent,
                ),
                if (label.trim().isNotEmpty) ...[
                  SizedBox(height: compact ? V5Spacing.xs : V5Spacing.sm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum V5DialogActionStyle { primary, secondary, destructive }

@immutable
class V5DialogAction {
  const V5DialogAction({
    this.key,
    required this.label,
    required this.onPressed,
    this.style = V5DialogActionStyle.secondary,
    this.loading = false,
  });

  final Key? key;
  final String label;
  final VoidCallback? onPressed;
  final V5DialogActionStyle style;
  final bool loading;
}

class V5Dialog extends StatelessWidget {
  const V5Dialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.icon,
    this.actions = const [],
  }) : assert(message != null || content != null);

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final List<V5DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return SafeArea(
      minimum: const EdgeInsets.all(V5Spacing.lg),
      child: Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(V5Spacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(V5Radius.large),
              border: Border.all(color: colors.outline.withValues(alpha: 0.72)),
              boxShadow: V5Elevation.level2(colors),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(V5Radius.control),
                      ),
                      child: Icon(icon, color: colors.textPrimary, size: 22),
                    ),
                    const SizedBox(height: V5Spacing.md),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (message case final text? when text.trim().isNotEmpty) ...[
                    const SizedBox(height: V5Spacing.xs),
                    Text(text, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (content != null) ...[
                    const SizedBox(height: V5Spacing.md),
                    content!,
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: V5Spacing.xl),
                    _V5DialogActions(actions: actions),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showV5Dialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final colors = context.v5Colors;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: colors.shadow.withValues(alpha: 0.32),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class V5Confirmation extends StatelessWidget {
  const V5Confirmation({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
    this.confirmLabel = 'Confirmer',
    this.cancelLabel = 'Annuler',
    this.destructive = false,
    this.loading = false,
    this.icon,
    this.confirmKey,
    this.cancelKey,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final bool loading;
  final IconData? icon;
  final Key? confirmKey;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) {
    return V5Dialog(
      title: title,
      message: message,
      icon:
          icon ??
          (destructive ? Icons.warning_amber_rounded : Icons.help_outline),
      actions: [
        V5DialogAction(key: cancelKey, label: cancelLabel, onPressed: onCancel),
        V5DialogAction(
          key: confirmKey,
          label: confirmLabel,
          onPressed: loading ? null : onConfirm,
          style: destructive
              ? V5DialogActionStyle.destructive
              : V5DialogActionStyle.primary,
          loading: loading,
        ),
      ],
    );
  }
}

Future<bool?> showV5Confirmation({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
  bool barrierDismissible = true,
  IconData? icon,
  Key? confirmKey,
  Key? cancelKey,
}) {
  return showV5Dialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => V5Confirmation(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
      confirmKey: confirmKey,
      cancelKey: cancelKey,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
}

enum V5ToastTone { neutral, success, warning, danger, info }

class V5Toast extends StatelessWidget {
  const V5Toast({
    super.key,
    required this.message,
    this.tone = V5ToastTone.neutral,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final V5ToastTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  static V5ToastController show(
    BuildContext context, {
    required String message,
    V5ToastTone tone = V5ToastTone.neutral,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    late OverlayEntry entry;
    late V5ToastController controller;
    entry = OverlayEntry(
      builder: (_) => _V5ToastOverlay(
        message: message,
        tone: tone,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        reduceMotion: reduceMotion,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
        onControllerReady: (dismiss) => controller._bind(dismiss),
      ),
    );
    controller = V5ToastController();
    overlay.insert(entry);
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final palette = _toastPalette(tone, colors);
    return SafeArea(
      minimum: const EdgeInsets.all(V5Spacing.md),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: message,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(V5Radius.section),
                border: Border.all(
                  color: palette.foreground.withValues(alpha: 0.18),
                ),
                boxShadow: V5Elevation.level2(colors),
              ),
              child: Row(
                children: [
                  Icon(
                    icon ?? palette.icon,
                    color: palette.foreground,
                    size: 20,
                  ),
                  const SizedBox(width: V5Spacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: V5Spacing.xs),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V5Spacing.xs,
                        vertical: V5Spacing.xs,
                      ),
                      onPressed: onAction,
                      child: Text(
                        actionLabel!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                    ),
                  ] else if (onDismiss != null)
                    CupertinoButton(
                      padding: const EdgeInsets.all(V5Spacing.xs),
                      onPressed: onDismiss,
                      child: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class V5ToastController {
  VoidCallback? _dismiss;
  bool _dismissRequested = false;

  void _bind(VoidCallback dismiss) {
    _dismiss = dismiss;
    if (_dismissRequested) dismiss();
  }

  void dismiss() {
    _dismissRequested = true;
    _dismiss?.call();
  }
}

class _V5FieldLabel extends StatelessWidget {
  const _V5FieldLabel({
    required this.label,
    required this.enabled,
    required this.child,
    this.excludeLabelSemantics = false,
  });

  final String label;
  final bool enabled;
  final Widget child;
  final bool excludeLabelSemantics;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          excluding: excludeLabelSemantics,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: enabled ? colors.textPrimary : colors.disabledForeground,
            ),
          ),
        ),
        const SizedBox(height: V5Spacing.xs),
        child,
      ],
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  String? hint,
  String? supportingText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  required bool enabled,
  required bool multiline,
}) {
  final colors = context.v5Colors;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(V5Radius.control),
    borderSide: BorderSide(color: colors.outline),
  );
  return InputDecoration(
    hintText: hint,
    helperText: supportingText,
    errorText: errorText,
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: enabled ? colors.surfaceElevated : colors.surfaceMuted,
    contentPadding: EdgeInsets.symmetric(
      horizontal: V5Spacing.md,
      vertical: multiline ? V5Spacing.md : 15,
    ),
    hintStyle: Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
    helperStyle: Theme.of(context).textTheme.bodySmall,
    errorStyle: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.danger),
    border: border,
    enabledBorder: border,
    disabledBorder: border.copyWith(
      borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.64)),
    ),
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.accent, width: 1.5),
    ),
    errorBorder: border.copyWith(borderSide: BorderSide(color: colors.danger)),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(color: colors.danger, width: 1.5),
    ),
  );
}

class _V5PickerFormField extends StatelessWidget {
  const _V5PickerFormField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.icon,
    required this.onTap,
    this.supportingText,
    this.errorText,
    this.leading,
    this.semanticValue,
    this.focusNode,
  });

  final String label;
  final String? value;
  final String placeholder;
  final String? supportingText;
  final String? errorText;
  final bool enabled;
  final IconData icon;
  final Widget? leading;
  final String? semanticValue;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final hasError = errorText != null;
    final foreground = enabled ? colors.textPrimary : colors.disabledForeground;
    return _V5FieldLabel(
      label: label,
      enabled: enabled,
      excludeLabelSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            enabled: enabled,
            label: label,
            value: semanticValue ?? value,
            onTap: enabled ? onTap : null,
            excludeSemantics: true,
            child: CupertinoButton(
              focusNode: focusNode,
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(V5Radius.control),
              onPressed: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: V5Spacing.md,
                  vertical: V5Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: enabled ? colors.surfaceElevated : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(V5Radius.control),
                  border: Border.all(
                    color: hasError ? colors.danger : colors.outline,
                  ),
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      IconTheme(
                        data: IconThemeData(color: foreground, size: 20),
                        child: leading!,
                      ),
                      const SizedBox(width: V5Spacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        value ?? placeholder,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: value == null
                              ? colors.textSecondary
                              : foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: V5Spacing.sm),
                    Icon(icon, size: 19, color: colors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          if (errorText case final error?) ...[
            const SizedBox(height: V5Spacing.xxs),
            Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.danger),
            ),
          ] else if (supportingText case final support?) ...[
            const SizedBox(height: V5Spacing.xxs),
            Text(support, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _V5SelectionSheet<T> extends StatelessWidget {
  const _V5SelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<V5SelectOption<T>> options;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                V5Spacing.lg,
                V5Spacing.lg,
                V5Spacing.lg,
                V5Spacing.sm,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  V5Spacing.lg,
                  V5Spacing.md,
                  V5Spacing.lg,
                  V5Spacing.xl,
                ),
                child: Text(
                  'Aucune option disponible.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: V5Spacing.lg),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: V5Spacing.lg,
                    color: colors.outline,
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == selectedValue;
                    final onTap = option.enabled
                        ? () => Navigator.of(context).pop(option.value)
                        : null;
                    return Semantics(
                      button: true,
                      enabled: option.enabled,
                      selected: selected,
                      label: option.label,
                      value: option.subtitle,
                      onTap: onTap,
                      excludeSemantics: true,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V5Spacing.lg,
                          vertical: V5Spacing.sm,
                        ),
                        onPressed: onTap,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: option.enabled
                                              ? colors.textPrimary
                                              : colors.textSecondary,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                  ),
                                  if (option.subtitle case final subtitle?) ...[
                                    const SizedBox(height: V5Spacing.xxs),
                                    Text(
                                      subtitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: V5Spacing.sm),
                              Icon(Icons.check_rounded, color: colors.accent),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _V5PickerSheet extends StatelessWidget {
  const _V5PickerSheet({
    required this.title,
    required this.child,
    required this.onConfirm,
  });

  final String title;
  final Widget child;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final useStackedHeader = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final cancel = CupertinoButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
    );
    final confirm = CupertinoButton(
      onPressed: onConfirm,
      child: Text(
        'Valider',
        style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
      ),
    );
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V5Spacing.sm,
              V5Spacing.xs,
              V5Spacing.sm,
              V5Spacing.xxs,
            ),
            child: useStackedHeader
                ? Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Expanded(child: cancel),
                          Expanded(child: confirm),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      cancel,
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      confirm,
                    ],
                  ),
          ),
          Divider(height: 1, color: colors.outline),
          CupertinoTheme(
            data: CupertinoTheme.of(context).copyWith(
              brightness: Theme.of(context).brightness,
              scaffoldBackgroundColor: colors.surfaceElevated,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 21,
                ),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _V5DialogActions extends StatelessWidget {
  const _V5DialogActions({required this.actions});

  final List<V5DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.length > 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            _V5DialogActionButton(action: actions[index]),
            if (index < actions.length - 1)
              const SizedBox(height: V5Spacing.xs),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          Expanded(child: _V5DialogActionButton(action: actions[index])),
          if (index < actions.length - 1) const SizedBox(width: V5Spacing.xs),
        ],
      ],
    );
  }
}

class _V5DialogActionButton extends StatelessWidget {
  const _V5DialogActionButton({required this.action});

  final V5DialogAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final label = action.loading
        ? const SizedBox.square(
            dimension: 18,
            child: CupertinoActivityIndicator(radius: 9),
          )
        : Text(action.label);
    return switch (action.style) {
      V5DialogActionStyle.secondary => OutlinedButton(
        key: action.key,
        onPressed: action.onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V5Radius.control),
          ),
        ),
        child: label,
      ),
      V5DialogActionStyle.primary => V5Button(
        key: action.key,
        onPressed: action.onPressed,
        expanded: true,
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        loading: action.loading,
        label: action.label,
      ),
      V5DialogActionStyle.destructive => V5Button(
        key: action.key,
        onPressed: action.onPressed,
        expanded: true,
        backgroundColor: colors.danger,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A080D)
            : Colors.white,
        loading: action.loading,
        label: action.label,
      ),
    };
  }
}

class _V5ToastOverlay extends StatefulWidget {
  const _V5ToastOverlay({
    required this.message,
    required this.tone,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.reduceMotion,
    required this.onDismissed,
    required this.onControllerReady,
  });

  final String message;
  final V5ToastTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final bool reduceMotion;
  final VoidCallback onDismissed;
  final ValueChanged<VoidCallback> onControllerReady;

  @override
  State<_V5ToastOverlay> createState() => _V5ToastOverlayState();
}

class _V5ToastOverlayState extends State<_V5ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Timer? _timer;
  bool _dismissing = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    widget.onControllerReady(_dismiss);
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.reduceMotion) {
      _animation.duration = Duration.zero;
      _animation.reverseDuration = Duration.zero;
    }
    _animation.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    await _animation.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final toast = IgnorePointer(
      ignoring: widget.onAction == null,
      child: V5Toast(
        message: widget.message,
        tone: widget.tone,
        icon: widget.icon,
        actionLabel: widget.actionLabel,
        onAction: widget.onAction == null
            ? null
            : () {
                widget.onAction!();
                _dismiss();
              },
        onDismiss: widget.onAction == null ? null : _dismiss,
      ),
    );
    if (widget.reduceMotion) {
      return Positioned(left: 0, right: 0, bottom: 0, child: toast);
    }
    final curved = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: toast,
        ),
      ),
    );
  }
}

({Color foreground, Color background, IconData icon}) _toastPalette(
  V5ToastTone tone,
  V5Colors colors,
) => switch (tone) {
  V5ToastTone.neutral => (
    foreground: colors.textSecondary,
    background: colors.surfaceElevated,
    icon: Icons.info_outline_rounded,
  ),
  V5ToastTone.success => (
    foreground: colors.success,
    background: colors.successContainer,
    icon: Icons.check_circle_outline_rounded,
  ),
  V5ToastTone.warning => (
    foreground: colors.warning,
    background: colors.warningContainer,
    icon: Icons.warning_amber_rounded,
  ),
  V5ToastTone.danger => (
    foreground: colors.danger,
    background: colors.dangerContainer,
    icon: Icons.error_outline_rounded,
  ),
  V5ToastTone.info => (
    foreground: colors.info,
    background: colors.infoContainer,
    icon: Icons.info_outline_rounded,
  ),
};
