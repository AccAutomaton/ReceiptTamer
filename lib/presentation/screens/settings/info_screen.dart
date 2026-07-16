import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';

/// Generic info screen for displaying Markdown policy or license content.
class InfoScreen extends StatelessWidget {
  final String title;
  final String markdownAssetPath;

  const InfoScreen({
    super.key,
    required this.title,
    required this.markdownAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: ScrollEdgeFog(
        showBottom: false,
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(markdownAssetPath),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '内容加载失败',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: snapshot.data!,
                selectable: true,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  h1: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  code: theme.textTheme.bodySmall?.copyWith(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
