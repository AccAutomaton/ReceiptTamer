import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../../data/models/app_version.dart';
import '../../../data/services/release_history_cache.dart';
import '../../../data/services/update_service.dart';
import '../../widgets/common/empty_state.dart';

/// Release history screen showing all GitHub releases
class ReleaseHistoryScreen extends StatefulWidget {
  const ReleaseHistoryScreen({super.key});

  @override
  State<ReleaseHistoryScreen> createState() => _ReleaseHistoryScreenState();
}

class _ReleaseHistoryScreenState extends State<ReleaseHistoryScreen> {
  final UpdateService _updateService = UpdateService();

  List<AppVersion> _releases = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  int _currentPage = 1;
  String? _errorMessage;
  bool _rateLimited = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadReleases();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _updateService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages && !_isLoading && !_isRefreshing) {
        _loadMoreReleases();
      }
    }
  }

  Future<void> _loadReleases({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() {
        _isRefreshing = true;
        _currentPage = 1;
        _hasMorePages = true;
        _errorMessage = null;
        _rateLimited = false;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _rateLimited = false;
      });
    }

    // Try to load cache first (if not force refresh)
    List<AppVersion>? cachedReleases;
    if (!forceRefresh) {
      cachedReleases = await ReleaseHistoryCache.getCache();
      if (cachedReleases != null && cachedReleases.isNotEmpty) {
        setState(() {
          _releases = cachedReleases!;
          _isLoading = false;
        });
      }
    }

    // Fetch from network
    final result = await _updateService.fetchAllReleases(
      perPage: 30,
      page: 1,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _releases = result.releases;
        _isLoading = false;
        _isRefreshing = false;
        _hasMorePages = result.nextPage != null;
        _currentPage = 1;
      });

      // Save to cache
      await ReleaseHistoryCache.saveCache(result.releases);
    } else {
      // Handle error
      if (cachedReleases != null && cachedReleases.isNotEmpty && !forceRefresh) {
        // Have cache, show toast
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _showErrorToast(result.errorMessage, result.rateLimited);
      } else {
        // No cache, show error state
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = result.errorMessage;
          _rateLimited = result.rateLimited;
        });
      }
    }
  }

  Future<void> _loadMoreReleases() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;
    final result = await _updateService.fetchAllReleases(
      perPage: 30,
      page: nextPage,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _releases.addAll(result.releases);
        _isLoadingMore = false;
        _hasMorePages = result.nextPage != null;
        _currentPage = nextPage;
      });

      // Update cache with all releases
      await ReleaseHistoryCache.saveCache(_releases);
    } else {
      setState(() {
        _isLoadingMore = false;
      });
      _showErrorToast(result.errorMessage, result.rateLimited);
    }
  }

  Future<void> _onRefresh() async {
    await _loadReleases(forceRefresh: true);
  }

  void _showErrorToast(String? errorMessage, bool rateLimited) {
    String message;
    if (rateLimited) {
      message = '检查更新请求因 GitHub 限流被拒绝，请前往 GitHub 仓库查看最新版本。';
    } else {
      message = '刷新失败: ${errorMessage ?? "未知错误"}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('更新历史'),
        elevation: 0,
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    // Loading state (no cache)
    if (_isLoading && _releases.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state (no cache)
    if (_errorMessage != null && _releases.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: _rateLimited
              ? 'GitHub API 请求受限'
              : '加载失败',
          subtitle: _rateLimited
              ? '请前往 GitHub 仓库查看最新版本'
              : _errorMessage ?? '未知错误',
          actionLabel: '重试',
          onAction: () => _loadReleases(forceRefresh: true),
        ),
      );
    }

    // Empty state (no releases)
    if (_releases.isEmpty && !_isLoading && !_isRefreshing) {
      return Center(
        child: EmptyState(
          icon: Icons.history_outlined,
          title: '暂无发布记录',
          subtitle: 'GitHub 仓库暂无版本发布',
        ),
      );
    }

    // Release list with refresh
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _releases.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _releases.length) {
            // Loading more indicator
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final release = _releases[index];
          return _buildReleaseCard(release, theme, colorScheme);
        },
      ),
    );
  }

  Widget _buildReleaseCard(
    AppVersion release,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Version tag
                Text(
                  release.tagName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                // Pre-release badge
                if (release.isPreRelease) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pre-release',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Date
                Text(
                  _formatDate(release.publishedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Changelog
            if (release.changelog != null && release.changelog!.isNotEmpty)
              MarkdownBody(
                data: release.changelog!,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  h2: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            if (release.changelog == null || release.changelog!.isEmpty)
              Text(
                '无更新说明',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}