import 'package:flutter/material.dart';

/// Generic info screen for displaying policy or license content
class InfoScreen extends StatelessWidget {
  final String title;
  final String content;

  const InfoScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}