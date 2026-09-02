import 'package:flutter/material.dart';

/// Live token streaming view with collapsible reasoning/thinking block support.
class StreamingTextView extends StatefulWidget {
  /// Creates a [StreamingTextView].
  const StreamingTextView({
    super.key,
    required this.stream,
    this.initialText = '',
  });

  /// The token stream to consume.
  final Stream<String> stream;

  /// Optional initial buffer text.
  final String initialText;

  @override
  State<StreamingTextView> createState() => _StreamingTextViewState();
}

class _StreamingTextViewState extends State<StreamingTextView> {
  final ScrollController _scrollController = ScrollController();
  final StringBuffer _thinkingBuffer = StringBuffer();
  final StringBuffer _contentBuffer = StringBuffer();
  bool _isThinking = false;
  bool _showThinking = true;

  @override
  void initState() {
    super.initState();
    _contentBuffer.write(widget.initialText);
    widget.stream.listen(_onToken, onError: (_) {});
  }

  void _onToken(String token) {
    if (!mounted) return;

    setState(() {
      var remaining = token;
      if (remaining.contains('<think>')) {
        _isThinking = true;
        final parts = remaining.split('<think>');
        _contentBuffer.write(parts[0]);
        remaining = parts.sublist(1).join('<think>');
      }

      if (_isThinking && remaining.contains('</think>')) {
        final parts = remaining.split('</think>');
        _thinkingBuffer.write(parts[0]);
        _isThinking = false;
        _contentBuffer.write(parts.sublist(1).join('</think>'));
        return;
      }

      if (_isThinking) {
        _thinkingBuffer.write(remaining);
      } else {
        _contentBuffer.write(remaining);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_thinkingBuffer.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12.0),
                    ),
                    onTap: () => setState(() => _showThinking = !_showThinking),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.psychology,
                            size: 18,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'Model Reasoning (${_isThinking ? "Thinking..." : "Finished"})',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showThinking
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showThinking)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        _thinkingBuffer.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          SelectableText(
            _contentBuffer.isEmpty
                ? 'Waiting for tokens...'
                : _contentBuffer.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
