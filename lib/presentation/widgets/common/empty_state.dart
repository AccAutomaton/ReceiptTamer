import 'package:flutter/material.dart';

/// Empty state component with icon and message
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customWidget;
  final double iconSize;
  final bool isCompact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.customWidget,
    this.iconSize = 64,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isCompact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize * 0.7,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (customWidget != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: customWidget),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state for orders
class EmptyOrders extends StatelessWidget {
  final VoidCallback? onAdd;

  const EmptyOrders({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: '暂无订单记录',
      subtitle: '点击下方按钮添加新订单',
      actionLabel: '添加订单',
      onAction: onAdd,
    );
  }
}

/// Empty state for invoices
class EmptyInvoices extends StatelessWidget {
  final VoidCallback? onAdd;

  const EmptyInvoices({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.description_outlined,
      title: '暂无发票记录',
      subtitle: '点击下方按钮添加新发票',
      actionLabel: '添加发票',
      onAction: onAdd,
    );
  }
}

/// Empty state for search results
class EmptySearchResults extends StatelessWidget {
  final VoidCallback? onClear;

  const EmptySearchResults({super.key, this.onClear});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: '未找到匹配的结果',
      subtitle: '尝试调整搜索条件',
      actionLabel: '清除搜索',
      onAction: onClear,
    );
  }
}

/// Empty state for errors
class EmptyError extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const EmptyError({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: '出错了',
      subtitle: message ?? '加载失败，请重试',
      actionLabel: onRetry != null ? '重试' : null,
      onAction: onRetry,
    );
  }
}

/// Empty state for network issues
class EmptyNetwork extends StatelessWidget {
  final VoidCallback? onRetry;

  const EmptyNetwork({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off,
      title: '网络连接失败',
      subtitle: '请检查网络设置后重试',
      actionLabel: '重试',
      onAction: onRetry,
    );
  }
}

/// Compact empty state for small spaces
class EmptyStateCompact extends StatelessWidget {
  final String message;

  const EmptyStateCompact({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      title: message,
      iconSize: 48,
      isCompact: true,
    );
  }
}
