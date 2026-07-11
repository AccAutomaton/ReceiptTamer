import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    required this.onCenterPressed,
  }) : assert(items.length == 4, 'GlassNavigationBar expects four tab items.');

  final int selectedIndex;
  final List<GlassNavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCenterPressed;

  static const double islandHeight = 72;
  static const double compactIslandHeight = 68;
  static const double centerActionSize = 54;
  static const double compactCenterActionSize = 51;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final compact = mediaSize.width <= 360;
    final horizontalInset = compact ? 12.0 : 14.0;
    final bottomInset = compact ? 10.0 : 12.0;
    final effectiveIslandHeight = compact ? compactIslandHeight : islandHeight;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navShadow = [
      BoxShadow(
        color: AppPalette.shadowDeep.withValues(alpha: isDark ? 0.34 : 0.18),
        blurRadius: 24,
        spreadRadius: -6,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: AppPalette.actionOutlineFor(
          context,
          alpha: isDark ? 0.10 : 0.08,
        ),
        blurRadius: 14,
        spreadRadius: -8,
        offset: const Offset(0, 1),
      ),
    ];

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        bottomInset,
      ),
      child: SizedBox(
        width: double.infinity,
        height: effectiveIslandHeight,
        child: RepaintBoundary(
          child: GlassSurface(
            key: const ValueKey('glass_nav_island'),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(compact ? 24 : 26),
              bottom: Radius.circular(compact ? 18 : 20),
            ),
            fillColor: AppGlassTokens.panelFillFor(context),
            blurSigma: 12,
            preset: GlassSurfacePreset.navigation,
            boxShadow: navShadow,
            edgeIntensity: 0.44,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 7 : 9,
                compact ? 6 : 7,
                compact ? 7 : 9,
                compact ? 7 : 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavButton(
                      index: 0,
                      item: items[0],
                      selectedIndex: selectedIndex,
                      onTap: onDestinationSelected,
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      index: 1,
                      item: items[1],
                      selectedIndex: selectedIndex,
                      onTap: onDestinationSelected,
                    ),
                  ),
                  SizedBox(
                    width: compact ? 62 : 68,
                    child: Center(
                      child: _CenterAction(
                        size: compact
                            ? compactCenterActionSize
                            : centerActionSize,
                        onPressed: onCenterPressed,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      index: 2,
                      item: items[2],
                      selectedIndex: selectedIndex,
                      onTap: onDestinationSelected,
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      index: 3,
                      item: items[3],
                      selectedIndex: selectedIndex,
                      onTap: onDestinationSelected,
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

class _CenterAction extends StatefulWidget {
  const _CenterAction({required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  State<_CenterAction> createState() => _CenterActionState();
}

class _CenterActionState extends State<_CenterAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = AppPalette.actionPrimaryFor(context);
    final reduceMotion = AppMotion.reduceMotion(context);
    final showPressedState = _pressed && !reduceMotion;
    final ridgeColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.22),
      primary,
    );
    final faceRadius = widget.size <= 51 ? 15.0 : 16.0;

    return AnimatedSlide(
      duration: AppMotion.adaptive(context, AppMotion.fast),
      curve: Curves.easeOutCubic,
      offset: showPressedState ? const Offset(0, 0.035) : Offset.zero,
      child: AnimatedScale(
        duration: AppMotion.adaptive(context, AppMotion.fast),
        curve: Curves.easeOutCubic,
        scale: showPressedState ? 0.96 : 1,
        child: SizedBox(
          key: const ValueKey('glass_nav_center_action'),
          width: widget.size,
          height: widget.size,
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ridgeColor,
                borderRadius: BorderRadius.circular(faceRadius + 1),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.24),
                    blurRadius: 14,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(faceRadius),
                  fillColor: primary,
                  borderColor: colorScheme.onPrimary.withValues(alpha: 0.48),
                  blurSigma: 0,
                  preset: GlassSurfacePreset.panel,
                  boxShadow: const [],
                  edgeIntensity: 0.48,
                  child: Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(faceRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(faceRadius),
                      onHighlightChanged: (pressed) {
                        if (_pressed == pressed) return;
                        setState(() => _pressed = pressed);
                      },
                      onTap: widget.onPressed,
                      child: Icon(
                        Icons.add,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.index,
    required this.item,
    required this.selectedIndex,
    required this.onTap,
  });

  final int index;
  final GlassNavItem item;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.index == widget.selectedIndex;
    final selectedColor = AppPalette.actionPrimaryFor(context);
    final unselectedColor = AppPalette.actionSecondaryFor(context);
    final unselectedIconColor = unselectedColor.withValues(alpha: 0.82);
    final reduceMotion = AppMotion.reduceMotion(context);
    final showPressedState = _pressed && !reduceMotion;

    return AnimatedScale(
      duration: AppMotion.adaptive(context, AppMotion.fast),
      curve: Curves.easeOutCubic,
      scale: showPressedState ? 0.97 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onHighlightChanged: (pressed) {
            if (_pressed == pressed) return;
            setState(() => _pressed = pressed);
          },
          onTap: () => widget.onTap(widget.index),
          child: AnimatedContainer(
            duration: AppMotion.adaptive(
              context,
              const Duration(milliseconds: 180),
            ),
            curve: Curves.easeOutCubic,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: AppMotion.adaptive(
                    context,
                    const Duration(milliseconds: 180),
                  ),
                  curve: Curves.easeOutCubic,
                  top: selected ? 1 : -4,
                  child: AnimatedOpacity(
                    duration: AppMotion.adaptive(
                      context,
                      const Duration(milliseconds: 180),
                    ),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: selectedColor.withValues(alpha: 0.28),
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? widget.item.selectedIcon : widget.item.icon,
                      size: 20,
                      color: selected ? selectedColor : unselectedIconColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? selectedColor : unselectedColor,
                        fontWeight: FontWeight.w700,
                      ),
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
