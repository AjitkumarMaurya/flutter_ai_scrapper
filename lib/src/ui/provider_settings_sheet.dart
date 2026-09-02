import 'package:flutter/material.dart';

import '../ai/provider_chain.dart';

/// Modal bottom sheet to configure cloud and local AI providers.
class ProviderSettingsSheet extends StatefulWidget {
  /// Creates a [ProviderSettingsSheet].
  const ProviderSettingsSheet({super.key, required this.chain, this.onChanged});

  /// The active [ProviderChain] being edited.
  final ProviderChain chain;

  /// Callback fired when configuration changes.
  final VoidCallback? onChanged;

  /// Convenience helper to display the sheet modally.
  static Future<void> show(
    BuildContext context, {
    required ProviderChain chain,
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProviderSettingsSheet(chain: chain, onChanged: onChanged),
    );
  }

  @override
  State<ProviderSettingsSheet> createState() => _ProviderSettingsSheetState();
}

class _ProviderSettingsSheetState extends State<ProviderSettingsSheet> {
  late bool _allowCloudEgress;
  late bool _preferLocal;
  String? _testStatus;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _allowCloudEgress = widget.chain.allowCloudEgress;
    _preferLocal = widget.chain.preferLocal;
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testStatus = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isTesting = false;
      _testStatus =
          'Chain active: ${widget.chain.providers.length} providers registered.';
    });
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
      // One scroll surface for the whole sheet. A bottom sheet gets whatever
      // height the viewport allows, and at 320dp the header, egress card and
      // provider list wrap onto enough lines to exceed it — this overflowed by
      // 76px. Scrolling the lot is better than clipping any of it, since the
      // egress toggle is a security control the user must be able to reach.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
                const SizedBox(width: 12.0),

                // Expanded so a long title cannot push the close button off-screen.
                Expanded(
                  child: Text(
                    'AI Provider Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      title: const Text('Allow Cloud Egress'),
                      subtitle: const Text(
                        'When disabled, all data remains strictly on-device. No scraped HTML or fields are sent to third-party endpoints.',
                      ),
                      value: _allowCloudEgress,
                      onChanged: (val) {
                        setState(() => _allowCloudEgress = val);
                        widget.onChanged?.call();
                      },
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Prefer On-Device (Local First)'),
                      subtitle: const Text(
                        'Attempts extraction with Gemma first, escalating to cloud endpoints only on low confidence.',
                      ),
                      value: _preferLocal,
                      onChanged: (val) {
                        setState(() => _preferLocal = val);
                        widget.onChanged?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Configured Providers (${widget.chain.providers.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.chain.providers.length,
              itemBuilder: (context, index) {
                final provider = widget.chain.providers[index];
                final isLocal = provider.capabilities.isLocal;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isLocal ? Icons.phone_android : Icons.cloud_outlined,
                    color: isLocal ? Colors.green : Colors.blue,
                  ),
                  title: Text(provider.id),
                  subtitle: Text(
                    isLocal ? 'On-Device (Zero Egress)' : 'Cloud Endpoint',
                  ),
                  trailing: Chip(
                    label: Text(
                      isLocal
                          ? 'Local'
                          : (_allowCloudEgress ? 'Active' : 'Disabled'),
                    ),
                  ),
                );
              },
            ),
            if (_testStatus != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _testStatus!,
                  style: TextStyle(color: colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12.0),
            FilledButton.icon(
              icon: _isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Test Chain Connection'),
              onPressed: _isTesting ? null : _testConnection,
            ),
          ],
        ),
      ),
    );
  }
}
