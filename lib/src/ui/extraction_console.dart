import 'package:flutter/material.dart';

import '../ai/ai_provider.dart';
import '../ai/cost_tracker.dart';
import '../api/ai_scrapper.dart';
import '../recipe/store.dart';
import '../structured/mapper.dart';
import 'result_viewer.dart';

/// Stage in the extraction lifecycle.
enum PipelineStage {
  idle,
  fetching,
  deterministicMetadata,
  recipeRunner,
  aiInference,
  complete,
  error,
}

/// Interactive console providing end-to-end web scraping across all pipeline tiers.
class ExtractionConsole extends StatefulWidget {
  /// Creates an [ExtractionConsole].
  const ExtractionConsole({
    super.key,
    required this.provider,
    this.recipeStore,
    this.sampleUrls = const [
      'https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html',
      'https://news.ycombinator.com',
    ],
  });

  /// The active AI provider or chain.
  final AiProvider provider;

  /// Optional recipe store for zero-inference executions.
  final RecipeStore? recipeStore;

  /// Preset sample URLs.
  final List<String> sampleUrls;

  @override
  State<ExtractionConsole> createState() => _ExtractionConsoleState();
}

class _ExtractionConsoleState extends State<ExtractionConsole> {
  late final TextEditingController _urlController;
  late final TextEditingController _queryController;

  PipelineStage _stage = PipelineStage.idle;
  StructuredHarvestResult? _result;
  String? _errorMessage;
  final UsageSession _session = UsageSession();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.sampleUrls.isNotEmpty ? widget.sampleUrls.first : '',
    );
    _queryController = TextEditingController(
      text: 'extract book title and price',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _executeScrape() async {
    final url = _urlController.text.trim();
    final query = _queryController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _stage = PipelineStage.fetching;
      _errorMessage = null;
      _result = null;
    });

    try {
      // Stage 1: Fetch
      final page = await AiScrapper.scrape(url);

      if (!mounted) return;
      setState(() => _stage = PipelineStage.recipeRunner);

      // Stage 2 & 3: Ask via recipes / AI
      final askResult = await page.ask(
        query,
        provider: widget.provider,
        recipeStore: widget.recipeStore,
      );

      if (mounted) {
        setState(() {
          _stage = PipelineStage.complete;
          _result = askResult.harvestResult;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = PipelineStage.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Target URL',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _urlController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _queryController,
            decoration: InputDecoration(
              labelText: 'Natural Language Query / Intent',
              prefixIcon: const Icon(Icons.psychology),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              FilledButton.icon(
                icon: _stage == PipelineStage.fetching ||
                        _stage == PipelineStage.recipeRunner ||
                        _stage == PipelineStage.aiInference
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Extract'),
                onPressed: _stage == PipelineStage.fetching ? null : _executeScrape,
              ),
              const SizedBox(width: 12.0),
              _buildPipelineStatusChip(colorScheme),
              const Spacer(),
              Text(
                'Tokens: ${_session.totalTokens} | \$${_session.estimatedTotalCost.toStringAsFixed(4)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
          const SizedBox(height: 16.0),
          const Divider(),
          Expanded(
            child: _result != null
                ? ResultViewer(result: _result!)
                : Center(
                    child: Text(
                      'Ready. Enter a URL and tap Extract.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStatusChip(ColorScheme scheme) {
    final (label, color) = switch (_stage) {
      PipelineStage.idle => ('Idle', Colors.grey),
      PipelineStage.fetching => ('Fetching HTML', Colors.orange),
      PipelineStage.deterministicMetadata => ('Metadata Harvest', Colors.green),
      PipelineStage.recipeRunner => ('Recipe / AI Stage', Colors.blue),
      PipelineStage.aiInference => ('AI Inference', Colors.purple),
      PipelineStage.complete => ('Complete', Colors.green),
      PipelineStage.error => ('Failed', Colors.red),
    };

    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 4),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
