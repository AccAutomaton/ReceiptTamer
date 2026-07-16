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

/// 主导航与新增收件入口组成的底部工作台。
///
/// 四个业务目的地保持连续，新增入口作为右侧独立实体侧键呈现，避免打断
/// “首页 → 订单 → 发票 → 报销”的信息结构。
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    this.onIntakePressed,
    @Deprecated('请改用 onIntakePressed。') this.onCenterPressed,
  }) : assert(items.length == 4, 'GlassNavigationBar expects four tab items.'),
       assert(
         onIntakePressed != null || onCenterPressed != null,
         '必须提供新增收件入口回调。',
       );

  final int selectedIndex;
  final List<GlassNavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onIntakePressed;

  /// 迁移期兼容旧调用点；视觉上不再存在中央按钮。
  @Deprecated('请改用 onIntakePressed。')
  final VoidCallback? onCenterPressed;

  static const double islandHeight = 72;
  static const double compactIslandHeight = 68;
  static const double intakeActionSize = 72;
  static const double compactIntakeActionSize = 68;
  static const double dockGap = 8;
  static const double contentFadeGap = 8;

  /// Vertical area that scrolling content must clear before reaching the dock.
  ///
  /// It mirrors this widget's compact geometry and [SafeArea] minimum, then
  /// leaves a small paper-colored gap so the fade finishes just above the dock.
  static double contentFadeInset(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final dockHeight = compact ? compactIslandHeight : islandHeight;
    final minimumBottomInset = compact ? 10.0 : 12.0;
    final safeBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final dockBottomInset = safeBottomInset > minimumBottomInset
        ? safeBottomInset
        : minimumBottomInset;

    return dockHeight + dockBottomInset + contentFadeGap;
  }

  VoidCallback get _effectiveIntakePressed =>
      onIntakePressed ?? onCenterPressed!;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final horizontalInset = compact ? 12.0 : 14.0;
    final bottomInset = compact ? 10.0 : 12.0;
    final height = compact ? compactIslandHeight : islandHeight;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        bottomInset,
      ),
      child: SizedBox(
        key: const ValueKey('main_bottom_dock'),
        width: double.infinity,
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RepaintBoundary(
                child: GlassSurface(
                  key: const ValueKey('glass_nav_island'),
                  borderRadius: BorderRadius.circular(compact ? 23 : 25),
                  fillColor: AppGlassTokens.panelFillFor(context),
                  blurSigma: 10,
                  preset: GlassSurfacePreset.navigation,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      children: [
                        for (var index = 0; index < items.length; index++)
                          Expanded(
                            child: _NavButton(
                              index: index,
                              item: items[index],
                              selectedIndex: selectedIndex,
                              compact: compact,
                              onTap: onDestinationSelected,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: dockGap),
            _IntakeAction(
              size: compact ? compactIntakeActionSize : intakeActionSize,
              onPressed: _effectiveIntakePressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntakeAction extends StatelessWidget {
  const _IntakeAction({required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = AppPalette.actionPrimaryFor(context);
    final compact = size <= GlassNavigationBar.compactIntakeActionSize;
    final radius = compact ? 20.0 : 22.0;

    return Semantics(
      button: true,
      label: '新增',
      child: Tooltip(
        message: '新增订单或发票',
        child: SizedBox.square(
          key: const ValueKey('glass_nav_intake_action'),
          dimension: size,
          child: Material(
            color: primary,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: colorScheme.onPrimary.withValues(alpha: 0.32),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: colorScheme.onPrimary,
                    size: compact ? 23 : 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '新增',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1,
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.index,
    required this.item,
    required this.selectedIndex,
    required this.compact,
    required this.onTap,
  });

  final int index;
  final GlassNavItem item;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final selectedColor = AppPalette.actionPrimaryFor(context);
    final unselectedColor = AppPalette.actionSecondaryFor(context);
    final radius = compact ? 15.0 : 17.0;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: AppMotion.adaptive(
              context,
              const Duration(milliseconds: 180),
            ),
            curve: Curves.easeOutCubic,
            height: compact ? 50 : 54,
            decoration: BoxDecoration(
              color: selected
                  ? AppPalette.selectedFillFor(context)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 19,
                  color: selected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? selectedColor : unselectedColor,
                    fontWeight: FontWeight.w700,
                    height: 1,
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
