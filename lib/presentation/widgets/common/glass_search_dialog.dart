import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

Future<String?> showGlassSearchDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String initialValue = '',
}) {
  final isDark = AppPalette.isDark(context);

  return showDialog<String>(
    context: context,
    barrierColor: Theme.of(
      context,
    ).colorScheme.scrim.withValues(alpha: isDark ? 0.48 : 0.32),
    builder: (dialogContext) =>
        GlassSearchDialog(title: title, hint: hint, initialValue: initialValue),
  );
}

class GlassSearchDialog extends StatefulWidget {
  const GlassSearchDialog({
    super.key,
    required this.title,
    required this.hint,
    this.initialValue = '',
  });

  final String title;
  final String hint;
  final String initialValue;

  @override
  State<GlassSearchDialog> createState() => _GlassSearchDialogState();
}

class _GlassSearchDialogState extends State<GlassSearchDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: RepaintBoundary(
          child: GlassSurface(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            fillColor: AppGlassTokens.sheetFillFor(context),
            blurSigma: 12,
            preset: GlassSurfacePreset.dialog,
            borderRadius: BorderRadius.circular(AppRadii.glassLarge),
            edgeIntensity: 0.48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppPalette.actionSoftFillFor(
                          context,
                          alpha: 0.82,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        border: Border.all(
                          color: AppPalette.actionOutlineFor(
                            context,
                            alpha: 0.34,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.search,
                        color: AppPalette.actionPrimaryFor(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hint: widget.hint,
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      text: '取消',
                      type: AppButtonType.text,
                      onPressed: () => Navigator.of(context).pop(),
                      isDense: true,
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      text: '搜索',
                      icon: const Icon(Icons.search, size: 18),
                      onPressed: _submit,
                      isDense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
