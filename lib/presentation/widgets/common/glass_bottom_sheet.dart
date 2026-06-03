import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.darkSurface.withValues(alpha: 0.24),
    builder: builder,
  );
}

class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: GlassSurface(
        fillColor: AppGlassTokens.sheetFill,
        preset: GlassSurfacePreset.sheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
          bottom: Radius.circular(AppRadii.sheet),
        ),
        boxShadow: AppShadows.glass,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class GlassActionTile extends StatelessWidget {
  const GlassActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildTile({required bool glass}) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: glass
                  ? AppPalette.actionSoftFill.withValues(alpha: 0.58)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: glass
                          ? AppPalette.actionContainer
                          : AppPalette.selectedFill,
                      borderRadius: BorderRadius.circular(16),
                      border: glass
                          ? Border.all(
                              color: AppPalette.actionOutline.withValues(
                                alpha: 0.46,
                              ),
                            )
                          : Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.72,
                              ),
                            ),
                    ),
                    child: Icon(icon, color: AppPalette.actionPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppPalette.actionPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return buildTile(glass: true);
  }
}
