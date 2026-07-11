import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

class MutedStatusChip extends StatelessWidget {
  const MutedStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall;
    final chipWash = color.withValues(alpha: 0.13);
    final effectiveBackground = Color.alphaBlend(
      chipWash,
      AppEntityTokens.fillFor(context),
    );
    final requestedForeground = color.withValues(alpha: 1);
    final foregroundColor =
        _contrastRatio(requestedForeground, effectiveBackground) >=
            _minimumTextContrast
        ? requestedForeground
        : theme.colorScheme.onSurface;

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // Pre-composited to keep ordinary content surfaces fully opaque.
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 13, color: foregroundColor),
            SizedBox(width: compact ? 3 : 4),
          ],
          Text(
            label,
            style: labelStyle?.copyWith(
              fontSize: compact ? (labelStyle.fontSize ?? 11) - 1 : null,
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

const _minimumTextContrast = 4.5;

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
