import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:receipt_tamer/core/utils/date_formatter.dart';

/// App Text Field - Unified text field widget with consistent styling
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final String? helperText;
  final String? counterText;
  final bool enabled;
  final bool required;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final EdgeInsetsGeometry? contentPadding;
  final double? borderRadius;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.helperText,
    this.counterText,
    this.enabled = true,
    this.required = false,
    this.focusNode,
    this.textCapitalization = TextCapitalization.sentences,
    this.contentPadding,
    this.borderRadius,
    this.onEditingComplete,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveHint = hint;
    final effectivePadding = contentPadding ??
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        );
    final effectiveBorderRadius = borderRadius ?? 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          required
              ? RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: ' *',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  label!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller ?? TextEditingController(text: initialValue ?? ''),
          onChanged: onChanged,
          onTap: onTap,
          readOnly: readOnly,
          obscureText: obscureText,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          enabled: enabled,
          focusNode: focusNode,
          textCapitalization: textCapitalization,
          onEditingComplete: onEditingComplete,
          onSubmitted: onSubmitted,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: effectiveHint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            errorText: errorText,
            helperText: helperText,
            counterText: counterText,
            filled: true,
            fillColor: enabled
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: effectivePadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// App Amount Field - specialized text field for monetary amounts
class AppAmountField extends StatelessWidget {
  final String? label;
  final String? hint;
  final double? initialValue;
  final TextEditingController? controller;
  final ValueChanged<double>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool required;
  final FocusNode? focusNode;

  const AppAmountField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.required = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final textEditingController = controller ?? TextEditingController(
      text: initialValue?.toStringAsFixed(2) ?? '',
    );

    return AppTextField(
      label: label,
      hint: hint ?? '0.00',
      controller: textEditingController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 16, right: 8),
        child: Align(
          widthFactor: 1.0,
          child: Text('¥', style: TextStyle(fontSize: 18)),
        ),
      ),
      errorText: errorText,
      helperText: helperText,
      enabled: enabled,
      required: required,
      focusNode: focusNode,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: (value) {
        final amount = double.tryParse(value);
        if (amount != null && onChanged != null) {
          onChanged!(amount);
        }
      },
    );
  }
}

/// App Date Field - specialized text field for date selection
class AppDateField extends StatelessWidget {
  final String? label;
  final String? hint;
  final DateTime? initialValue;
  final TextEditingController? controller;
  final ValueChanged<DateTime>? onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool required;
  final FocusNode? focusNode;

  const AppDateField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.required = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final textEditingController = controller ?? TextEditingController(
      text: initialValue != null
          ? DateFormatter.formatDisplayWithWeekday(initialValue!)
          : '',
    );

    return AppTextField(
      label: label,
      hint: hint ?? '选择日期',
      controller: textEditingController,
      readOnly: true,
      onTap: enabled
          ? () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialValue ?? now,
                firstDate: firstDate ?? DateTime(now.year - 10),
                lastDate: lastDate ?? DateTime(now.year + 10),
              );
              if (picked != null && onChanged != null) {
                onChanged!(picked);
                textEditingController.text = DateFormatter.formatDisplayWithWeekday(picked);
              }
            }
          : null,
      prefixIcon: const Icon(Icons.calendar_today_outlined),
      errorText: errorText,
      helperText: helperText,
      enabled: enabled,
      required: required,
      focusNode: focusNode,
    );
  }
}

/// App Select Field - specialized text field for selecting from options
class AppSelectField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<T> options;
  final String Function(T) displayValue;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool required;
  final FocusNode? focusNode;
  final Widget Function(T)? leadingBuilder;

  const AppSelectField({
    super.key,
    this.label,
    this.hint,
    this.value,
    required this.options,
    required this.displayValue,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.required = false,
    this.focusNode,
    this.leadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveHint = hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          required
              ? RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: ' *',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  label!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: enabled
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText != null
                  ? Colors.red
                  : colorScheme.outline.withOpacity(0.3),
              width: errorText != null ? 1 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              items: options.map((option) {
                return DropdownMenuItem<T>(
                  value: option,
                  child: Text(
                    displayValue(option),
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: enabled ? onChanged : null,
              hint: Text(
                effectiveHint ?? '请选择',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              decoration: InputDecoration(
                errorText: errorText,
                helperText: helperText,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
              focusNode: focusNode,
            ),
          ),
        ),
      ],
    );
  }
}
