import 'package:flutter/material.dart';

/// A sleek fast scroll bar that displays month indicators on the right edge.
/// Shows a bubble with year/month when dragging, and jumps to that position on release.
class MonthFastScrollBar extends StatefulWidget {
  final List<MonthScrollItem> items;
  final void Function(int index) onJumpToIndex;
  final double width;

  const MonthFastScrollBar({
    super.key,
    required this.items,
    required this.onJumpToIndex,
    this.width = 32,
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
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.primaryContainer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.year}年',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              '${item.month}月',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
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
    return (ratio * widget.items.length).floor().clamp(0, widget.items.length - 1);
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

  _ScrollBarPainter({
    required this.items,
    required this.hoveredIndex,
    required this.colorScheme,
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
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, topPadding),
      Offset(centerX, size.height - bottomPadding),
      railPaint,
    );

    // Background color for text (to hide rail behind numbers)
    final bgPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.fill;

    // Styles for different states
    final normalStyle = TextStyle(
      fontSize: 8,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
      final y = topPadding + (i / (items.length - 1).clamp(1, items.length)) * railHeight;

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

        // Draw background to hide rail
        canvas.drawRect(
          Rect.fromLTWH(
            centerX - yearPainter.width / 2 - 2,
            y - 16,
            yearPainter.width + 4,
            yearPainter.height + 2,
          ),
          bgPaint,
        );

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
      final textSpan = TextSpan(
        text: '${item.month}',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Draw background to hide rail behind text
      canvas.drawRect(
        Rect.fromLTWH(
          centerX - textPainter.width / 2 - 2,
          y - textPainter.height / 2 - 1,
          textPainter.width + 4,
          textPainter.height + 2,
        ),
        bgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollBarPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex || oldDelegate.items != items;
  }
}