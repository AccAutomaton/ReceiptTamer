import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

enum LedgerRelationTone { neutral, linked, action }

const ledgerMonthFadeSafeTop = 28.0;
const ledgerMonthSheetRadius = 16.0;

/// Clips a ledger scroll viewport to the same rounded top edge as its pinned
/// month sheet.
///
/// A pinned sliver header is transparent outside its rounded corners. Without
/// this viewport clip, rows scrolling behind that header can show through the
/// corner cut-outs as square paper patches. Clipping the scrolling content —
/// instead of painting a solid guard over it — keeps the page background
/// genuinely continuous around the sheet.
class LedgerViewportClip extends StatelessWidget {
  final Widget child;
  final double horizontalInset;
  final double topRadius;

  const LedgerViewportClip({
    super.key,
    required this.child,
    this.horizontalInset = 16,
    this.topRadius = ledgerMonthSheetRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _LedgerViewportClipper(
        horizontalInset: horizontalInset,
        topRadius: topRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LedgerViewportClipper extends CustomClipper<Path> {
  final double horizontalInset;
  final double topRadius;

  const _LedgerViewportClipper({
    required this.horizontalInset,
    required this.topRadius,
  });

  @override
  Path getClip(Size size) {
    final inset = horizontalInset.clamp(0, size.width / 2).toDouble();
    final radius = Radius.circular(topRadius);
    final roundedTop = RRect.fromRectAndCorners(
      Rect.fromLTRB(inset, 0, size.width - inset, size.height),
      topLeft: radius,
      topRight: radius,
    );
    final fullWidthStart = topRadius.clamp(0, size.height).toDouble();

    return Path()
      ..addRRect(roundedTop)
      // Only the two corner cut-outs need masking. Restore the full viewport
      // below the radius so empty states and edge-originated drag gestures are
      // never constrained by the ledger sheet's horizontal inset.
      ..addRect(Rect.fromLTRB(0, fullWidthStart, size.width, size.height));
  }

  @override
  bool shouldReclip(covariant _LedgerViewportClipper oldClipper) {
    return oldClipper.horizontalInset != horizontalInset ||
        oldClipper.topRadius != topRadius;
  }
}

class LedgerFilterStrip extends StatelessWidget {
  final List<Widget> children;

  const LedgerFilterStrip({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            children[index],
          ],
        ],
      ),
    );
  }
}

class LedgerFilterChip extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final IconData? icon;
  final bool selected;
  final VoidCallback onPressed;

  const LedgerFilterChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.icon,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppPalette.actionPrimaryFor(context)
        : AppPalette.textSecondaryFor(context);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: ShapeDecoration(
                  color: selected
                      ? AppPalette.actionContainerFor(context, alpha: 0.72)
                      : AppEntityTokens.fillFor(context),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected
                          ? AppPalette.actionOutlineFor(context, alpha: 0.66)
                          : AppEntityTokens.borderFor(context),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: foreground),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One continuous paper sheet for a calendar month.
///
/// The header and entries share the same surface so rows read as a ledger,
/// rather than as a stack of unrelated cards.
class LedgerMonthSheet extends StatelessWidget {
  final String monthLabel;
  final String summary;
  final String totalLabel;
  final String totalAmount;
  final List<Widget> entries;

  const LedgerMonthSheet({
    super.key,
    required this.monthLabel,
    required this.summary,
    required this.totalLabel,
    required this.totalAmount,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppEntityTokens.borderFor(context);
    final radius = const BorderRadius.all(
      Radius.circular(ledgerMonthSheetRadius),
    );

    return _LedgerSheetSegment(
      border: Border.all(color: borderColor),
      borderRadius: radius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LedgerMonthHeader(
            monthLabel: monthLabel,
            summary: summary,
            totalLabel: totalLabel,
            totalAmount: totalAmount,
          ),
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withValues(alpha: 0.82),
              ),
            entries[index],
          ],
        ],
      ),
    );
  }
}

/// A calendar month rendered as one bounded sliver group.
///
/// Keeping the persistent header and its rows in the same
/// [SliverMainAxisGroup] makes the header sticky only while that month's rows
/// are still visible. The next month then replaces it instead of allowing a
/// detached header to float over unrelated data.
class LedgerMonthSheetSliver extends StatelessWidget {
  static const headerSurfaceKey = ValueKey<String>(
    'ledger-month-sheet-header-surface',
  );
  static const entriesSurfaceKey = ValueKey<String>(
    'ledger-month-sheet-entries-surface',
  );

  final String monthLabel;
  final String summary;
  final String totalLabel;
  final String totalAmount;
  final List<Widget> entries;
  final EdgeInsetsGeometry padding;

  const LedgerMonthSheetSliver({
    super.key,
    required this.monthLabel,
    required this.summary,
    required this.totalLabel,
    required this.totalAmount,
    required this.entries,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final sheetWidth =
            (constraints.crossAxisExtent - resolvedPadding.horizontal)
                .clamp(0.0, double.infinity)
                .toDouble();

        return SliverPadding(
          padding: resolvedPadding,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _LedgerMonthHeaderDelegate(
                  extent: ledgerMonthHeaderExtent(
                    context,
                    sheetWidth: sheetWidth,
                  ),
                  monthLabel: monthLabel,
                  summary: summary,
                  totalLabel: totalLabel,
                  totalAmount: totalAmount,
                ),
              ),
              SliverToBoxAdapter(child: _LedgerMonthEntries(entries: entries)),
            ],
          ),
        );
      },
    );
  }
}

/// Returns the fixed extent needed by a sticky month header at the active text
/// scale. The regular and stacked calculations mirror [_LedgerMonthHeader]'s
/// typography and spacing so accessibility text never overflows the sliver.
double ledgerMonthHeaderExtent(BuildContext context, {double? sheetWidth}) {
  // Text boxes with explicit line heights can still differ by a few logical
  // pixels across bundled serif fallback/rasterizer combinations. Keep that
  // variance below the copy so the 28dp fade-safe band remains untouched.
  const fontMetricSafety = 4.0;
  final scaler = MediaQuery.textScalerOf(context);
  // Use a representative body size instead of scale(1). The app's additive
  // one-pixel type step would make scale(1) report 2 at the default platform
  // scale and almost double the sticky-header extent.
  final scale = scaler.scale(14) / 14;
  final estimatedSheetWidth =
      sheetWidth ?? MediaQuery.sizeOf(context).width - 32;
  final usesStackedLayout = estimatedSheetWidth < 280 || scaler.scale(14) >= 22;

  if (usesStackedLayout) {
    // At compact widths the scaled year/month label wraps to a second line.
    // Include that line in the fixed sliver extent instead of clipping it.
    final wrappedMonthLine = estimatedSheetWidth <= 360 ? 22.1 * scale : 0;
    return (72.45 * scale + 77 + wrappedMonthLine + fontMetricSafety)
        .ceilToDouble();
  }
  return (36.6 * scale + 62 + fontMetricSafety)
      .clamp(101, double.infinity)
      .ceilToDouble();
}

class _LedgerMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final String monthLabel;
  final String summary;
  final String totalLabel;
  final String totalAmount;

  const _LedgerMonthHeaderDelegate({
    required this.extent,
    required this.monthLabel,
    required this.summary,
    required this.totalLabel,
    required this.totalAmount,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final borderColor = AppEntityTokens.borderFor(context);

    return SizedBox.expand(
      child: RepaintBoundary(
        child: _LedgerSheetSegment(
          key: LedgerMonthSheetSliver.headerSurfaceKey,
          border: Border(
            top: BorderSide(color: borderColor),
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(ledgerMonthSheetRadius),
            topRight: Radius.circular(ledgerMonthSheetRadius),
          ),
          child: _LedgerMonthHeader(
            monthLabel: monthLabel,
            summary: summary,
            totalLabel: totalLabel,
            totalAmount: totalAmount,
            fadeSafeTop: true,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LedgerMonthHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent ||
        oldDelegate.monthLabel != monthLabel ||
        oldDelegate.summary != summary ||
        oldDelegate.totalLabel != totalLabel ||
        oldDelegate.totalAmount != totalAmount;
  }
}

class _LedgerMonthEntries extends StatelessWidget {
  final List<Widget> entries;

  const _LedgerMonthEntries({required this.entries});

  @override
  Widget build(BuildContext context) {
    final borderColor = AppEntityTokens.borderFor(context);

    return _LedgerSheetSegment(
      key: LedgerMonthSheetSliver.entriesSurfaceKey,
      border: Border(
        left: BorderSide(color: borderColor),
        right: BorderSide(color: borderColor),
        bottom: BorderSide(color: borderColor),
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(ledgerMonthSheetRadius),
        bottomRight: Radius.circular(ledgerMonthSheetRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withValues(alpha: 0.82),
              ),
            entries[index],
          ],
        ],
      ),
    );
  }
}

class _LedgerMonthHeader extends StatelessWidget {
  final String monthLabel;
  final String summary;
  final String totalLabel;
  final String totalAmount;
  final bool fadeSafeTop;

  const _LedgerMonthHeader({
    required this.monthLabel,
    required this.summary,
    required this.totalLabel,
    required this.totalAmount,
    this.fadeSafeTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    Widget buildMonthCopy({required bool allowWrap}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            maxLines: allowWrap ? null : 1,
            softWrap: allowWrap,
            overflow: allowWrap ? TextOverflow.clip : TextOverflow.fade,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 17,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            maxLines: allowWrap ? null : 1,
            softWrap: allowWrap,
            overflow: allowWrap ? TextOverflow.clip : TextOverflow.fade,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              height: 1.45,
              color: AppPalette.textSecondaryFor(context),
            ),
          ),
        ],
      );
    }

    final totalCopy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          totalLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            height: 1.4,
            color: AppPalette.textSecondaryFor(context),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          totalAmount,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 19,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: AppPalette.amountFor(context),
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      header: true,
      label: '$monthLabel，$summary，$totalLabel $totalAmount',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: fadeSafeTop
              ? const EdgeInsets.fromLTRB(
                  17,
                  ledgerMonthFadeSafeTop,
                  14,
                  ledgerMonthFadeSafeTop,
                )
              : const EdgeInsets.fromLTRB(17, 12, 14, 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              AppPalette.actionContainerFor(context, alpha: 0.34),
              AppEntityTokens.fillFor(context),
            ),
            border: Border(
              bottom: BorderSide(
                color: AppEntityTokens.strongBorderFor(context),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useStackedLayout =
                  constraints.maxWidth < 280 || scaler.scale(14) >= 22;

              if (useStackedLayout) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildMonthCopy(allowWrap: true),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: totalCopy),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: buildMonthCopy(allowWrap: false)),
                  const SizedBox(width: 12),
                  totalCopy,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints the paper first, clips its contents to the segment shape, then paints
/// the segment boundary in the foreground. Ledger rows therefore cannot cover
/// the rounded outer boundary while the header and body still meet as one
/// continuous sheet.
class _LedgerSheetSegment extends StatelessWidget {
  final Border border;
  final BorderRadius borderRadius;
  final Widget child;

  const _LedgerSheetSegment({
    super.key,
    required this.border,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppEntityTokens.fillFor(context),
        borderRadius: borderRadius,
      ),
      foregroundDecoration: BoxDecoration(
        border: border,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// A flat ledger entry with a date rail, content, amount and relation state.
class LedgerEntryRow extends StatelessWidget {
  final String day;
  final String dateCaption;
  final String title;
  final String subtitle;
  final String amount;
  final String relationLabel;
  final LedgerRelationTone relationTone;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? leading;

  const LedgerEntryRow({
    super.key,
    required this.day,
    required this.dateCaption,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.relationLabel,
    this.relationTone = LedgerRelationTone.neutral,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final semanticsLabel =
        '$day 日，$dateCaption，$title，$subtitle，$amount，$relationLabel';

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? AppPalette.selectedFillFor(context)
              : AppEntityTokens.fillFor(context),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scaler = MediaQuery.textScalerOf(context);
                final useStackedLayout =
                    constraints.maxWidth < 270 || scaler.scale(13) >= 20;
                return useStackedLayout
                    ? _buildStacked(context)
                    : _buildInline(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    final leadingWidth = leading == null ? 0.0 : 36.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 77),
      child: Stack(
        children: [
          if (leading != null)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: leadingWidth,
              child: Center(child: leading),
            ),
          Positioned(
            top: 0,
            bottom: 0,
            left: leadingWidth,
            width: 52,
            child: _buildDateRail(context),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(leadingWidth + 64, 0, 13, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 77),
              child: Row(
                children: [
                  Expanded(child: _buildMainCopy(context)),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 74,
                      maxWidth: 112,
                    ),
                    child: _buildEndCopy(context, stacked: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStacked(BuildContext context) {
    final leadingWidth = leading == null ? 0.0 : 40.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 128),
      child: Stack(
        children: [
          if (leading != null)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: leadingWidth,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: leading,
                ),
              ),
            ),
          Positioned(
            top: 0,
            bottom: 0,
            left: leadingWidth,
            width: 58,
            child: _buildDateRail(context),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(leadingWidth + 72, 14, 14, 15),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 99),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMainCopy(context),
                  const SizedBox(height: 12),
                  _buildEndCopy(context, stacked: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRail(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = AppEntityTokens.borderFor(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: leading == null
              ? BorderSide.none
              : BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                day,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.amountFor(context),
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateCaption,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  height: 1.3,
                  color: AppPalette.textSecondaryFor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCopy(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 13,
            height: 1.38,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            height: 1.45,
            color: AppPalette.textSecondaryFor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEndCopy(BuildContext context, {required bool stacked}) {
    final theme = Theme.of(context);
    final relationColor = switch (relationTone) {
      LedgerRelationTone.neutral => AppPalette.textSecondaryFor(context),
      LedgerRelationTone.linked => AppPalette.actionPrimaryFor(context),
      LedgerRelationTone.action => AppPalette.actionSecondaryFor(context),
    };

    final amountWidget = Text(
      amount,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 15,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: AppPalette.amountFor(context),
        fontFeatures: AppTypography.tabularFigures,
      ),
    );
    final relationWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: relationTone == LedgerRelationTone.linked
                ? relationColor
                : Colors.transparent,
            border: Border.all(color: relationColor),
            borderRadius: relationTone == LedgerRelationTone.action
                ? BorderRadius.circular(1)
                : BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            relationLabel,
            maxLines: stacked ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: relationColor,
            ),
          ),
        ),
      ],
    );

    if (stacked) {
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [amountWidget, relationWidget],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [amountWidget, const SizedBox(height: 7), relationWidget],
    );
  }
}
