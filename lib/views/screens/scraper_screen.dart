import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/scraper_viewmodel.dart';
import '../../models/scrape_result.dart';
import '../widgets/scraper_form.dart';
import '../widgets/results_display.dart';

/// Main screen for the web scraper application
class ScraperScreen extends StatefulWidget {
  const ScraperScreen({super.key});

  @override
  State<ScraperScreen> createState() => _ScraperScreenState();
}

class _ScraperScreenState extends State<ScraperScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _tagController;
  late final TextEditingController _classController;
  late final TextEditingController _regexController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: 'https://example.com');
    _tagController = TextEditingController(text: 'h1');
    _classController = TextEditingController();
    _regexController = TextEditingController(text: r'<title>(.*?)</title>');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tagController.dispose();
    _classController.dispose();
    _regexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Mobile Scraper'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ScraperViewModel>(
            builder: (context, viewModel, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'clear_results':
                      viewModel.clearResults();
                      break;
                    case 'clear_history':
                      viewModel.clearHistory();
                      break;
                    case 'view_history':
                      _showHistoryDialog(context, viewModel);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_results',
                    child: ListTile(
                      leading: Icon(Icons.clear),
                      title: Text('Clear Results'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view_history',
                    child: ListTile(
                      leading: Icon(Icons.history),
                      title: Text('View History'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_history',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever),
                      title: Text('Clear History'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<ScraperViewModel>(
        builder: (context, viewModel, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Form section
                ScraperForm(
                  urlController: _urlController,
                  tagController: _tagController,
                  classController: _classController,
                  regexController: _regexController,
                  isLoading: viewModel.isLoading,
                  onTagScrape: () => _performTagScrape(viewModel),
                  onRegexScrape: () => _performRegexScrape(viewModel),
                ),
                const SizedBox(height: 16),

                // Results section
                Expanded(
                  child: ResultsDisplay(
                    result: viewModel.currentResult,
                    errorMessage:
                        viewModel.hasError ? viewModel.errorMessage : null,
                    isLoading: viewModel.isLoading,
                    onClear: viewModel.clearResults,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _performTagScrape(ScraperViewModel viewModel) {
    if (!_validateInput()) return;

    viewModel.scrapeByTag(
      url: _urlController.text.trim(),
      tag: _tagController.text.trim(),
      className: _classController.text.trim().isEmpty
          ? null
          : _classController.text.trim(),
    );
  }

  void _performRegexScrape(ScraperViewModel viewModel) {
    if (!_validateRegexInput()) return;

    viewModel.scrapeByRegex(
      url: _urlController.text.trim(),
      pattern: _regexController.text.trim(),
    );
  }

  bool _validateInput() {
    if (_urlController.text.trim().isEmpty) {
      _showSnackBar('Please enter a URL');
      return false;
    }

    if (_tagController.text.trim().isEmpty) {
      _showSnackBar('Please enter an HTML tag');
      return false;
    }

    return true;
  }

  bool _validateRegexInput() {
    if (_urlController.text.trim().isEmpty) {
      _showSnackBar('Please enter a URL');
      return false;
    }

    if (_regexController.text.trim().isEmpty) {
      _showSnackBar('Please enter a regex pattern');
      return false;
    }

    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, ScraperViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scraping History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: viewModel.scrapeHistory.isEmpty
              ? const Center(
                  child: Text('No scraping history yet'),
                )
              : ListView.builder(
                  itemCount: viewModel.scrapeHistory.length,
                  itemBuilder: (context, index) {
                    final result = viewModel.scrapeHistory[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          result.isSuccess ? Icons.check_circle : Icons.error,
                          color: result.isSuccess ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          result.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Type: ${result.type.displayName}'),
                            Text('Results: ${result.data.length} items'),
                            Text(
                              'Time: ${_formatTime(result.timestamp)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: result.isSuccess
                            ? Text('${result.data.length}')
                            : const Icon(Icons.error_outline,
                                color: Colors.red),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (viewModel.scrapeHistory.isNotEmpty)
            TextButton(
              onPressed: () {
                viewModel.clearHistory();
                Navigator.of(context).pop();
              },
              child: const Text('Clear All'),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
