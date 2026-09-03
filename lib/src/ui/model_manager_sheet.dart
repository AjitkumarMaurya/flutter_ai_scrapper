import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../ai/model_manager.dart';

/// Modal bottom sheet or dialog allowing users to manage on-device LLM models.
class ModelManagerSheet extends StatefulWidget {
  /// Creates a [ModelManagerSheet].
  const ModelManagerSheet({super.key, required this.manager});

  /// The underlying [ModelManager] instance.
  final ModelManager manager;

  /// Convenience method to show this sheet modally.
  static Future<void> show(
    BuildContext context, {
    required ModelManager manager,
  }) {
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
  final TextEditingController _hfTokenController = TextEditingController();
  bool _wifiOnly = true;
  bool _showTokenInput = false;
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

  @override
  void dispose() {
    _hfTokenController.dispose();
    super.dispose();
  }

  Future<void> _refreshStorage() async {
    try {
      final info = await widget.manager.getStorageInfo();
      final installed = await widget.manager.listInstalledModels();
      debugPrint('DEBUG _refreshStorage installed: $installed');
      if (mounted) {
        setState(() {
          _storageInfo = info;
          _installedRepos = installed.toSet();
        });
      }
    } catch (e) {
      debugPrint('DEBUG _refreshStorage error: $e');
    }
  }

  Future<void> _download(GemmaModelSpec model) async {
    setState(() {
      _downloadingRepo = model.repo;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    final token = _hfTokenController.text.trim().isEmpty
        ? null
        : _hfTokenController.text.trim();

    try {
      await widget.manager.install(
        model,
        token: token,
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
      if (model.file != null) {
        await widget.manager.uninstallModel(model.file!);
      }
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

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.memory, color: colorScheme.primary),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'On-Device Models',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showTokenInput ? Icons.vpn_key : Icons.vpn_key_outlined,
                    ),
                    tooltip: 'Hugging Face Token',
                    onPressed: () =>
                        setState(() => _showTokenInput = !_showTokenInput),
                  ),
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
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Download on Wi-Fi only'),
                value: _wifiOnly,
                onChanged: (val) => setState(() => _wifiOnly = val),
              ),
              if (_showTokenInput)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: _hfTokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'HF Access Token (optional)',
                      hintText: 'hf_...',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: SelectableText(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
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
                    _buildModelTile(
                      GemmaModels.gemma31b,
                      'Default on-device generalist (~550 MB)',
                    ),
                    _buildModelTile(
                      GemmaModels.functionGemma270m,
                      'Ultra-light 270M function specialist (~300 MB)',
                    ),
                    _buildModelTile(
                      GemmaModels.qwen306b,
                      'Multilingual 600M extractor (~400 MB)',
                    ),
                    _buildModelTile(
                      GemmaModels.gemma4E2b,
                      'High precision 2B edge model (~2.4 GB)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelTile(GemmaModelSpec model, String subtitle) {
    final isInstalled =
        _installedRepos.contains(model.repo) ||
        (model.file != null && _installedRepos.contains(model.file)) ||
        _installedRepos.any(
          (r) => model.file != null && r.endsWith(model.file!),
        );
    final isDownloading = _downloadingRepo == model.repo;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        title: Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              model.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${model.sizeBytes ~/ (1024 * 1024)} MB'),
            ),
            // A gated repo answers an anonymous download with 401. Saying so
            // up front turns "the download is broken" into "I need a token".
            if (model.gated)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.key, size: 14),
                label: const Text('Token'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 2.0),
            Text(
              '${model.repo} • ${model.file ?? "manifest"}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
                fontFamily: 'monospace',
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 8.0),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 4.0),
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
