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
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.34),
    builder: builder,
  );
}

/// Shows existing page content inside the shared floating glass sheet.
///
/// This intentionally mirrors the native bottom-sheet defaults used by the
/// legacy screens: the nearest navigator is used unless explicitly overridden,
/// dismiss/drag behavior is unchanged, and the builder receives the sheet
/// route's context. Only the route material and visual wrapper are replaced.
Future<T?> showGlassContentBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.34),
    shape: shape,
    builder: (sheetContext) =>
        GlassBottomSheet(shape: shape, child: builder(sheetContext)),
  );
}

class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
    this.shape,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final sheetShape = shape;
    final requestedRadius = sheetShape is RoundedRectangleBorder
        ? sheetShape.borderRadius.resolve(Directionality.of(context))
        : null;
    const fallbackRadius = Radius.circular(AppRadii.sheet);
    final topLeft = requestedRadius?.topLeft ?? fallbackRadius;
    final topRight = requestedRadius?.topRight ?? fallbackRadius;
    final borderRadius = BorderRadius.only(
      topLeft: topLeft == Radius.zero ? fallbackRadius : topLeft,
      topRight: topRight == Radius.zero ? fallbackRadius : topRight,
      bottomLeft: requestedRadius?.bottomLeft == Radius.zero
          ? (topLeft == Radius.zero ? fallbackRadius : topLeft)
          : requestedRadius?.bottomLeft ?? fallbackRadius,
      bottomRight: requestedRadius?.bottomRight == Radius.zero
          ? (topRight == Radius.zero ? fallbackRadius : topRight)
          : requestedRadius?.bottomRight ?? fallbackRadius,
    );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: RepaintBoundary(
        child: GlassSurface(
          preset: GlassSurfacePreset.sheet,
          fillColor: AppGlassTokens.sheetFillFor(context),
          blurSigma: 10,
          borderRadius: borderRadius,
          edgeIntensity: 0.48,
          child: Padding(padding: padding, child: child),
        ),
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
    final actionColor = AppPalette.actionPrimaryFor(context);
    final actionContainer = AppPalette.actionContainerFor(context);
    final selectedFill = AppPalette.selectedFillFor(context);

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
                  ? AppGlassTokens.contentFillFor(context)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: glass
                  ? Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: glass ? actionContainer : selectedFill,
                      borderRadius: BorderRadius.circular(16),
                      border: glass
                          ? Border.all(
                              color: AppPalette.actionOutlineFor(
                                context,
                                alpha: 0.46,
                              ),
                            )
                          : Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.72,
                              ),
                            ),
                    ),
                    child: Icon(icon, color: actionColor),
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
                            color: AppPalette.textPrimaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.textSecondaryFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: actionColor),
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
