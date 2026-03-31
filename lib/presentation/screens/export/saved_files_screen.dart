import 'package:flutter/material.dart';
import '../../../data/services/file_service.dart';

/// Saved file item model
class SavedFile {
  final String name;
  final String path;
  final int size;
  final int date;
  final String uri;

  SavedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.date,
    required this.uri,
  });

  factory SavedFile.fromMap(Map<String, dynamic> map) {
    return SavedFile(
      name: map['name'] as String,
      path: map['path'] as String,
      size: map['size'] as int,
      date: map['date'] as int,
      uri: map['uri'] as String,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(date);

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Saved directory model
class SavedDirectory {
  final String name;
  final String path;

  SavedDirectory({required this.name, required this.path});

  factory SavedDirectory.fromMap(Map<String, dynamic> map) {
    return SavedDirectory(
      name: map['name'] as String,
      path: map['path'] as String,
    );
  }
}

/// Screen to browse saved files in Download/ReceiptTamer
class SavedFilesScreen extends StatefulWidget {
  /// Initial sub-directory to display (e.g., "materials/20260331")
  final String initialSubDir;

  const SavedFilesScreen({super.key, this.initialSubDir = ''});

  @override
  State<SavedFilesScreen> createState() => _SavedFilesScreenState();
}

class _SavedFilesScreenState extends State<SavedFilesScreen> {
  final FileService _fileService = FileService();
  List<SavedDirectory> _directories = [];
  List<SavedFile> _files = [];
  bool _isLoading = true;
  String _currentPath = '';
  String _currentDisplayPath = '';

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialSubDir;
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load sub-directories
      _directories = await _loadDirectories(_currentPath);

      // Always load files (for root directory with APKs, or leaf directories)
      _files = await _loadFiles(_currentPath);

      // Update display path
      _currentDisplayPath = await _fileService.getDownloadDirectoryPath(subDir: _currentPath) ?? '';
    } catch (e) {
      debugPrint('Error loading content: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<List<SavedDirectory>> _loadDirectories(String parentDir) async {
    final dirs = await _fileService.listSubDirectories(parentDir: parentDir);
    return dirs.map((d) => SavedDirectory.fromMap(d)).toList();
  }

  Future<List<SavedFile>> _loadFiles(String subDir) async {
    final files = await _fileService.listFilesInDirectory(subDir: subDir);
    return files.map((f) => SavedFile.fromMap(f)).toList();
  }

  void _navigateToDirectory(SavedDirectory dir) {
    setState(() {
      _currentPath = dir.path;
    });
    _loadContent();
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;

    // Go up one level
    final parts = _currentPath.split('/');
    if (parts.length > 1) {
      setState(() {
        _currentPath = parts.sublist(0, parts.length - 1).join('/');
      });
    } else {
      setState(() {
        _currentPath = '';
      });
    }
    _loadContent();
  }

  Future<void> _shareFile(SavedFile file) async {
    final mimeType = _fileService.getMimeType(file.name);
    final success = await _fileService.shareFile(file.uri, file.name, mimeType);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分享失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          if (_currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: _navigateUp,
              tooltip: '返回上一级',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(theme),
    );
  }

  String _getAppBarTitle() {
    if (_currentPath.isEmpty) {
      return '导出的文件';
    }

    // Extract the deepest directory name
    final parts = _currentPath.split('/');
    final lastPart = parts.last;

    // Format date directory name (YYYYMMDD -> YYYY年MM月DD日)
    if (lastPart.length == 8 && int.tryParse(lastPart) != null) {
      final year = lastPart.substring(0, 4);
      final month = lastPart.substring(4, 6);
      final day = lastPart.substring(6, 8);
      return '$year年$month月$day日';
    }

    // Translate known directory names
    switch (lastPart) {
      case 'materials':
        return '报销材料';
      case 'backup':
        return '备份数据';
      default:
        return lastPart;
    }
  }

  Widget _buildContent(ThemeData theme) {
    if (_directories.isEmpty && _files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('暂无文件', style: theme.textTheme.bodyLarge),
            if (_currentDisplayPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _currentDisplayPath,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Show path info
        if (_currentDisplayPath.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '路径: $_currentDisplayPath',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        // Directory list
        ..._directories.map((dir) => _buildDirectoryItem(dir, theme)),

        // Divider between directories and files
        if (_directories.isNotEmpty && _files.isNotEmpty)
          const Divider(height: 1),

        // File list
        ..._files.map((file) => _buildFileItem(file, theme)),
      ],
    );
  }

  Widget _buildDirectoryItem(SavedDirectory dir, ThemeData theme) {
    // Format directory name for display
    String displayName = dir.name;

    // Format date directory (YYYYMMDD -> YYYY年MM月DD日)
    if (dir.name.length == 8 && int.tryParse(dir.name) != null) {
      final year = dir.name.substring(0, 4);
      final month = dir.name.substring(4, 6);
      final day = dir.name.substring(6, 8);
      displayName = '$year年$month月$day日';
    }

    return ListTile(
      leading: Icon(Icons.folder, color: theme.colorScheme.primary),
      title: Text(displayName),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _navigateToDirectory(dir),
    );
  }

  Widget _buildFileItem(SavedFile file, ThemeData theme) {
    return ListTile(
      leading: Icon(_getFileIcon(file.name), color: theme.colorScheme.primary),
      title: Text(file.name),
      subtitle: Text(
        '${file.formattedSize} · ${_formatDate(file.dateTime)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareFile(file),
        tooltip: '分享',
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'zip':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// Show saved files screen
Future<void> showSavedFilesScreen(BuildContext context, {String initialSubDir = ''}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SavedFilesScreen(initialSubDir: initialSubDir),
    ),
  );
}