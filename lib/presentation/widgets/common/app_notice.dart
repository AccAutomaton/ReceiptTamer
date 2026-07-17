import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_design_tokens.dart';

/// Visual semantics for the shared top-of-screen notice paper slip.
enum AppNoticeTone { info, success, warning, error, linkage }

/// A handle that only dismisses the notice created by the corresponding call.
class AppNoticeHandle {
  const AppNoticeHandle._(this._dismiss);

  final VoidCallback _dismiss;

  void dismiss() => _dismiss();
}

/// Shows one consistent, transient notice above the current route.
///
/// A new notice replaces the currently visible one. This mirrors the existing
/// reimbursement linkage feedback and prevents old messages from queuing after
/// the user has already moved on to a different operation.
class AppNotice {
  const AppNotice._();

  static const Duration defaultDuration = Duration(seconds: 4);
  static const Duration linkageDuration = Duration(milliseconds: 1800);
  static const Duration actionableDuration = Duration(seconds: 4);

  static Object? _activeToken;
  static VoidCallback? _activeRemoval;

  static AppNoticeHandle show(
    BuildContext context,
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) => _showOnOverlay(
    context.mounted ? Overlay.maybeOf(context, rootOverlay: true) : null,
    message,
    tone: tone,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    noticeKey: noticeKey,
  );

  /// Shows a notice in an already resolved overlay.
  ///
  /// Use this after the originating route has been popped and only its
  /// navigator remains alive; an [OverlayState.context] cannot discover the
  /// overlay that it owns through [Overlay.maybeOf].
  static AppNoticeHandle showOnOverlay(
    OverlayState overlay,
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) => _showOnOverlay(
    overlay.mounted ? overlay : null,
    message,
    tone: tone,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    noticeKey: noticeKey,
  );

  static AppNoticeHandle _showOnOverlay(
    OverlayState? overlay,
    String message, {
    required AppNoticeTone tone,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) {
    assert(
      actionLabel == null || onAction != null,
      'An AppNotice action label requires an action callback.',
    );

    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      dismiss();
      return const AppNoticeHandle._(_noop);
    }
    if (overlay == null) return const AppNoticeHandle._(_noop);

    dismiss();

    final token = Object();
    late final OverlayEntry entry;
    var disposed = false;

    void removeEntry() {
      if (disposed) return;
      disposed = true;
      if (_activeToken == token) {
        _activeToken = null;
        _activeRemoval = null;
      }
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (context) => _AppNoticeOverlay(
        message: normalizedMessage,
        tone: tone,
        duration:
            duration ??
            (actionLabel == null ? defaultDuration : actionableDuration),
        actionLabel: actionLabel,
        onAction: onAction,
        noticeKey: noticeKey,
        onDismissed: removeEntry,
        onUnmounted: () {
          scheduleMicrotask(() {
            if (!disposed && !entry.mounted) removeEntry();
          });
        },
      ),
    );
    _activeToken = token;
    _activeRemoval = removeEntry;
    overlay.insert(entry);

    return AppNoticeHandle._(() {
      if (_activeToken == token || entry.mounted) removeEntry();
    });
  }

  static AppNoticeHandle info(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) => show(
    context,
    message,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    noticeKey: noticeKey,
  );

  static AppNoticeHandle success(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.success,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    noticeKey: noticeKey,
  );

  static AppNoticeHandle warning(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.warning,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    noticeKey: noticeKey,
  );

  static AppNoticeHandle error(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    Key? noticeKey,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.error,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    noticeKey: noticeKey,
  );

  static void dismiss() {
    final remove = _activeRemoval;
    _activeRemoval = null;
    _activeToken = null;
    remove?.call();
  }

  static void _noop() {}
}

class _AppNoticeOverlay extends StatefulWidget {
  const _AppNoticeOverlay({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismissed,
    required this.onUnmounted,
    this.actionLabel,
    this.onAction,
    this.noticeKey,
  });

  final String message;
  final AppNoticeTone tone;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? noticeKey;
  final VoidCallback onDismissed;
  final VoidCallback onUnmounted;

  @override
  State<_AppNoticeOverlay> createState() => _AppNoticeOverlayState();
}

class _AppNoticeOverlayState extends State<_AppNoticeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curve,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -0.22),
    end: Offset.zero,
  ).animate(_opacity);
  Timer? _holdTimer;
  bool _started = false;
  bool _dismissing = false;
  bool _actionInvoked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final animationDuration = AppMotion.adaptive(context, AppMotion.standard);
    _controller
      ..duration = animationDuration
      ..reverseDuration = animationDuration
      ..forward();
    _holdTimer = Timer(widget.duration, () => unawaited(_dismiss()));
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _holdTimer?.cancel();
    try {
      await _controller.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onDismissed();
  }

  void _runAction() {
    if (_actionInvoked || _dismissing) return;
    _actionInvoked = true;
    try {
      widget.onAction?.call();
    } finally {
      unawaited(_dismiss());
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    widget.onUnmounted();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paperColor = Color.alphaBlend(
      AppPalette.textSecondaryFor(context).withValues(alpha: 0.035),
      AppEntityTokens.fillFor(context),
    );
    final accentColor = _accentColor(context, widget.tone);
    final actionLabel = widget.actionLabel;
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Positioned(
      top: viewPadding.top + 6,
      left: viewPadding.left + AppSpacing.page,
      right: viewPadding.right + AppSpacing.page,
      child: IgnorePointer(
        ignoring: actionLabel == null,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Material(
                    key: widget.noticeKey ?? const ValueKey('app-notice'),
                    color: paperColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      side: BorderSide(
                        color: AppEntityTokens.strongBorderFor(context),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconFor(widget.tone),
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              widget.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppPalette.textPrimaryFor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (actionLabel != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _runAction,
                              style: TextButton.styleFrom(
                                foregroundColor: accentColor,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(actionLabel),
                            ),
                          ],
                        ],
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

  Color _accentColor(BuildContext context, AppNoticeTone tone) =>
      switch (tone) {
        AppNoticeTone.info => AppPalette.actionSecondaryFor(context),
        AppNoticeTone.success =>
          AppPalette.isDark(context)
              ? Theme.of(context).colorScheme.primary
              : AppPalette.successMuted,
        AppNoticeTone.warning =>
          AppPalette.isDark(context)
              ? Theme.of(context).colorScheme.tertiary
              : AppPalette.warningMuted,
        AppNoticeTone.error => Theme.of(context).colorScheme.error,
        AppNoticeTone.linkage => AppPalette.textSecondaryFor(context),
      };

  IconData _iconFor(AppNoticeTone tone) => switch (tone) {
    AppNoticeTone.info => Icons.info_outline_rounded,
    AppNoticeTone.success => Icons.check_circle_outline_rounded,
    AppNoticeTone.warning => Icons.warning_amber_rounded,
    AppNoticeTone.error => Icons.error_outline_rounded,
    AppNoticeTone.linkage => Icons.link_rounded,
  };
}
