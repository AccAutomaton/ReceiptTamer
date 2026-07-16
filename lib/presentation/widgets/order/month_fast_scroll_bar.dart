import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

const monthFastScrollBarWidth = 32.0;
// The list stops 4dp before the rail's leading edge. Together with the sheet's
// own 16dp trailing padding, reserving half the rail plus 4dp keeps the rail
// distinct without repeating its entire width as empty page margin.
const monthFastScrollBarListRightInset = monthFastScrollBarWidth / 2 + 4;
const monthFastScrollBarBottomInset = AppGlassTokens.navCenterButtonSize + 44;

/// Reveals a lazily built month sheet without assuming fixed row heights.
///
/// The first jump uses item counts only to bring the target sliver into the
/// viewport cache. Once its [GlobalKey] has a context, [Scrollable.ensureVisible]
/// performs the precise alignment. This remains accurate when text scaling
/// changes the actual height of headers and entries.
Future<void> revealMonthAnchor({
  required ScrollController controller,
  required int targetIndex,
  required List<GlobalKey> anchors,
  required List<int> itemCounts,
  required Duration duration,
  bool Function()? isCurrent,
}) async {
  if (!controller.hasClients ||
      targetIndex < 0 ||
      targetIndex >= anchors.length ||
      anchors.length != itemCounts.length) {
    return;
  }

  bool requestIsCurrent() => isCurrent?.call() ?? true;

  Future<bool> alignBuiltAnchor() async {
    final anchorContext = anchors[targetIndex].currentContext;
    if (anchorContext == null || !requestIsCurrent()) return false;
    await Scrollable.ensureVisible(
      anchorContext,
      alignment: 0.02,
      duration: duration,
      curve: Curves.easeInOut,
    );
    return true;
  }

  if (await alignBuiltAnchor()) return;

  final position = controller.position;
  final totalWeight = itemCounts.fold<double>(
    0,
    (sum, count) => sum + (count < 0 ? 0 : count) + 1,
  );
  final precedingWeight = itemCounts
      .take(targetIndex)
      .fold<double>(0, (sum, count) => sum + (count < 0 ? 0 : count) + 1);
  final estimatedContentExtent =
      position.maxScrollExtent + position.viewportDimension;
  final estimatedOffset = totalWeight <= 0
      ? 0.0
      : estimatedContentExtent * precedingWeight / totalWeight;
  controller.jumpTo(estimatedOffset.clamp(0.0, position.maxScrollExtent));

  for (var attempt = 0; attempt < 12 && requestIsCurrent(); attempt++) {
    await WidgetsBinding.instance.endOfFrame;
    if (await alignBuiltAnchor()) return;

    final builtIndices = <int>[
      for (var index = 0; index < anchors.length; index++)
        if (anchors[index].currentContext != null) index,
    ];
    if (builtIndices.isEmpty || !controller.hasClients) return;

    final currentPosition = controller.position;
    final moveForward = targetIndex > builtIndices.last;
    final moveBackward = targetIndex < builtIndices.first;
    if (!moveForward && !moveBackward) return;

    final direction = moveForward ? 1.0 : -1.0;
    final nextOffset =
        (currentPosition.pixels +
                currentPosition.viewportDimension * 0.82 * direction)
            .clamp(0, currentPosition.maxScrollExtent);
    if ((nextOffset - currentPosition.pixels).abs() < 0.5) return;
    controller.jumpTo(nextOffset.toDouble());
  }
}

class MonthFastScrollLayout extends StatelessWidget {
  final Widget child;
  final List<MonthScrollItem> items;
  final void Function(int index) onJumpToIndex;
  final double scrollBarWidth;
  final double rightInset;
  final double bottomInset;
  final double? listRightInset;
  final Color labelBackgroundColor;

  const MonthFastScrollLayout({
    super.key,
    required this.child,
    required this.items,
    required this.onJumpToIndex,
    this.scrollBarWidth = monthFastScrollBarWidth,
    this.rightInset = 0,
    this.bottomInset = monthFastScrollBarBottomInset,
    this.listRightInset,
    this.labelBackgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    if (items.length <= 1) return child;

    final effectiveListRightInset = listRightInset ?? scrollBarWidth / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(right: effectiveListRightInset),
            child: child,
          ),
        ),
        Positioned(
          top: 0,
          right: rightInset,
          bottom: bottomInset,
          child: MonthFastScrollBar(
            items: items,
            onJumpToIndex: onJumpToIndex,
            width: scrollBarWidth,
            labelBackgroundColor: labelBackgroundColor,
          ),
        ),
      ],
    );
  }
}

/// A sleek fast scroll bar that displays month indicators on the right edge.
/// Shows a bubble with year/month when dragging, and jumps to that position on release.
class MonthFastScrollBar extends StatefulWidget {
  final List<MonthScrollItem> items;
  final void Function(int index) onJumpToIndex;
  final double width;
  final Color labelBackgroundColor;

  const MonthFastScrollBar({
    super.key,
    required this.items,
    required this.onJumpToIndex,
    this.width = 32,
    this.labelBackgroundColor = Colors.transparent,
  });

  @override
  State<MonthFastScrollBar> createState() => _MonthFastScrollBarState();
}

class _MonthFastScrollBarState extends State<MonthFastScrollBar> {
  bool _isDragging = false;
  int _hoveredIndex = 0;
  int _lastJumpedIndex = -1;
  double _dragY = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The scroll bar rail
        GestureDetector(
          onVerticalDragStart: (details) {
            _startDrag(details.localPosition.dy);
          },
          onVerticalDragUpdate: (details) {
            _updateDrag(details.localPosition.dy);
          },
          onVerticalDragEnd: (details) {
            _endDrag();
          },
          onTapDown: (details) {
            _startDrag(details.localPosition.dy);
          },
          onTapUp: (details) {
            _endDrag();
          },
          child: Container(
            width: widget.width,
            height: double.infinity,
            color: Colors.transparent,
            child: CustomPaint(
              painter: _ScrollBarPainter(
                items: widget.items,
                hoveredIndex: _isDragging ? _hoveredIndex : -1,
                colorScheme: colorScheme,
                labelBackgroundColor: widget.labelBackgroundColor,
              ),
            ),
          ),
        ),
        // The bubble indicator (only visible when dragging)
        if (_isDragging)
          Positioned(
            right: widget.width + 8,
            top: _dragY - 28,
            child: _buildBubble(colorScheme),
          ),
      ],
    );
  }

  Widget _buildBubble(ColorScheme colorScheme) {
    if (widget.items.isEmpty || _hoveredIndex >= widget.items.length) {
      return const SizedBox.shrink();
    }

    final item = widget.items[_hoveredIndex];

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      color: AppGlassTokens.sheetFillFor(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.year}年',
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.textSecondaryFor(context),
              ),
            ),
            Text(
              '${item.month}月',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.amountFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startDrag(double localY) {
    final index = _calculateIndex(localY);
    setState(() {
      _isDragging = true;
      _hoveredIndex = index;
      _dragY = localY;
    });
    // Jump immediately on start
    if (index != _lastJumpedIndex) {
      _lastJumpedIndex = index;
      widget.onJumpToIndex(index);
    }
  }

  void _updateDrag(double localY) {
    final index = _calculateIndex(localY);
    setState(() {
      _hoveredIndex = index;
      _dragY = localY;
    });
    // Jump in real-time while dragging
    if (index != _lastJumpedIndex) {
      _lastJumpedIndex = index;
      widget.onJumpToIndex(index);
    }
  }

  void _endDrag() {
    setState(() {
      _isDragging = false;
      _lastJumpedIndex = -1; // Reset for next drag session
    });
  }

  int _calculateIndex(double localY) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.height <= 0) return 0;

    final ratio = (localY / box.size.height).clamp(0.0, 1.0);
    return (ratio * widget.items.length).floor().clamp(
      0,
      widget.items.length - 1,
    );
  }
}

/// Data item for the scroll bar
class MonthScrollItem {
  final int year;
  final int month;

  const MonthScrollItem({required this.year, required this.month});
}

/// Custom painter for drawing the scroll bar rail
class _ScrollBarPainter extends CustomPainter {
  final List<MonthScrollItem> items;
  final int hoveredIndex;
  final ColorScheme colorScheme;
  final Color labelBackgroundColor;

  _ScrollBarPainter({
    required this.items,
    required this.hoveredIndex,
    required this.colorScheme,
    required this.labelBackgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final topPadding = 18.0; // Extra padding to avoid app bar overlap
    final bottomPadding = 12.0;
    final railHeight = size.height - topPadding - bottomPadding;
    final centerX = size.width / 2;

    // Draw the center rail line
    final railPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.62)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, topPadding),
      Offset(centerX, size.height - bottomPadding),
      railPaint,
    );

    final bgPaint = labelBackgroundColor.a > 0
        ? (Paint()
            ..color = labelBackgroundColor
            ..style = PaintingStyle.fill)
        : null;

    // Styles for different states
    final normalStyle = TextStyle(
      fontSize: 8,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
    );

    final yearMarkerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: colorScheme.primary,
    );

    final hoveredStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: colorScheme.primary,
    );

    int? currentYear;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final y =
          topPadding +
          (i / (items.length - 1).clamp(1, items.length)) * railHeight;

      final isHovered = i == hoveredIndex;
      final isYearStart = currentYear != item.year;
      currentYear = item.year;

      // For year starts, draw the year label above the month
      if (isYearStart && !isHovered) {
        final yearSpan = TextSpan(
          text: '${item.year}',
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w500,
            color: colorScheme.primary.withValues(alpha: 0.8),
          ),
        );
        final yearPainter = TextPainter(
          text: yearSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        if (bgPaint != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              centerX - yearPainter.width / 2 - 2,
              y - 16,
              yearPainter.width + 4,
              yearPainter.height + 2,
            ),
            bgPaint,
          );
        }

        yearPainter.paint(
          canvas,
          Offset(centerX - yearPainter.width / 2, y - 15),
        );
      }

      // Determine style based on state
      final textStyle = isHovered
          ? hoveredStyle
          : isYearStart
          ? yearMarkerStyle
          : normalStyle;

      // Draw month label centered on the rail
      final textSpan = TextSpan(text: '${item.month}', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      if (bgPaint != null) {
        canvas.drawRect(
          Rect.fromLTWH(
            centerX - textPainter.width / 2 - 2,
            y - textPainter.height / 2 - 1,
            textPainter.width + 4,
            textPainter.height + 2,
          ),
          bgPaint,
        );
      }

      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollBarPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.items != items ||
        oldDelegate.labelBackgroundColor != labelBackgroundColor;
  }
}
