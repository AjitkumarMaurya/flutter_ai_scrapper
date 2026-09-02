import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../ai/model_manager.dart';

/// Modal bottom sheet or dialog allowing users to manage on-device LLM models.
class ModelManagerSheet extends StatefulWidget {
  /// Creates a [ModelManagerSheet].
  const ModelManagerSheet({
    super.key,
    required this.manager,
  });

  /// The underlying [ModelManager] instance.
  final ModelManager manager;

  /// Convenience method to show this sheet modally.
  static Future<void> show(BuildContext context, {required ModelManager manager}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ModelManagerSheet(manager: manager),
    );
  }

  @override
  State<ModelManagerSheet> createState() => _ModelManagerSheetState();
}

class _ModelManagerSheetState extends State<ModelManagerSheet> {
  bool _wifiOnly = true;
  String? _errorMessage;
  String? _downloadingRepo;
  double _downloadProgress = 0.0;
  StorageStats? _storageInfo;
  Set<String> _installedRepos = {};

  @override
  void initState() {
    super.initState();
    _refreshStorage();
  }

  Future<void> _refreshStorage() async {
    try {
      final info = await widget.manager.getStorageInfo();
      final installed = await widget.manager.listInstalledModels();
      if (mounted) {
        setState(() {
          _storageInfo = info;
          _installedRepos = installed.toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _download(GemmaModelSpec model) async {
    setState(() {
      _downloadingRepo = model.repo;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      await widget.manager.install(
        model,
        onProgress: (p) {
          if (mounted) {
            setState(() => _downloadProgress = p);
          }
        },
      );
      await _refreshStorage();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingRepo = null);
      }
    }
  }

  Future<void> _delete(GemmaModelSpec model) async {
    try {
      await widget.manager.uninstallModel(model.repo);
      await _refreshStorage();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: colorScheme.primary),
              const SizedBox(width: 12.0),
              Text(
                'On-Device Models',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          if (_storageInfo != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'Models footprint: ${_storageInfo!.totalSizeMB.toStringAsFixed(1)} MB (${_storageInfo!.totalFiles} files)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SwitchListTile(
            dense: true,
            title: const Text('Download on Wi-Fi only'),
            value: _wifiOnly,
            onChanged: (val) => setState(() => _wifiOnly = val),
          ),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildModelTile(GemmaModels.gemma31b, 'Default on-device generalist'),
                _buildModelTile(GemmaModels.functionGemma270m, 'Ultra-light 270M function specialist'),
                _buildModelTile(GemmaModels.qwen306b, 'Multilingual 600M extractor'),
                _buildModelTile(GemmaModels.gemma4E2b, 'High precision 2B edge model'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelTile(GemmaModelSpec model, String subtitle) {
    final isInstalled = _installedRepos.contains(model.repo);
    final isDownloading = _downloadingRepo == model.repo;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        title: Row(
          children: [
            Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8.0),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${model.sizeBytes ~/ (1024 * 1024)} MB'),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (isDownloading) ...[
              const SizedBox(height: 8.0),
              LinearProgressIndicator(value: _downloadProgress),
              Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
        trailing: isInstalled
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Model',
                onPressed: () => _delete(model),
              )
            : isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Install'),
                    onPressed: () => _download(model),
                  ),
      ),
    );
  }
}
