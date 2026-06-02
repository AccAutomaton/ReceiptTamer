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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: AppGlassTokens.navCenterButtonSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 3,
              bottom: 3,
              child: GlassSurface(
                borderRadius: BorderRadius.circular(AppRadii.nav),
                child: Padding(
                  padding: const EdgeInsets.all(5),
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
                      const SizedBox(width: AppGlassTokens.navCenterSlotWidth),
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
            SizedBox(
              key: const ValueKey('glass_nav_center_action'),
              width: AppGlassTokens.navCenterButtonSize,
              height: AppGlassTokens.navCenterButtonSize,
              child: GlassSurface(
                borderRadius: BorderRadius.circular(AppRadii.nav),
                fillColor: AppPalette.actionPrimary,
                borderColor: Colors.white.withValues(alpha: 0.84),
                blurSigma: 30,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onCenterPressed,
                    child: const Icon(Icons.add, color: Colors.white, size: 31),
                  ),
                ),
              ),
            ),
          ],
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
    required this.onTap,
  });

  final int index;
  final GlassNavItem item;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.nav),
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.actionContainer.withValues(alpha: 0.86)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.nav),
          border: selected
              ? Border.all(
                  color: AppPalette.actionOutline.withValues(alpha: 0.36),
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              size: 20,
              color: selected
                  ? AppPalette.actionPrimary
                  : AppPalette.actionSecondary.withValues(alpha: 0.82),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? AppPalette.actionPrimary
                    : AppPalette.actionSecondary.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
