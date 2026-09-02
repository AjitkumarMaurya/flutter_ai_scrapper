import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';

/// Widget for displaying scraping results
class ResultsDisplay extends StatelessWidget {
  final ScrapeResult? result;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback? onClear;

  const ResultsDisplay({
    super.key,
    this.result,
    this.errorMessage,
    this.isLoading = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On a very short pane — a small phone with the keyboard open — the
          // card's own padding plus header can exceed the height available,
          // and the Column overflows before its content gets a chance to
          // scroll. Shedding the fixed chrome keeps it inside its bounds.
          final isTight = constraints.maxHeight < 160;

          // Below this there is not enough room for both a label and anything
          // under it. The content is what the user is here for, so the header
          // is what goes.
          final hideHeader = constraints.maxHeight < 110;

          return Padding(
            padding: EdgeInsets.all(isTight ? 8.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hideHeader) ...[
                  _buildHeader(context),
                  SizedBox(height: isTight ? 4 : 12),
                ],
                Expanded(child: _buildContent(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.receipt_long,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Results',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (result != null)
                Text(
                  '${result!.data.length} items found • ${result!.type.displayName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (result != null && onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear results',
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scraping website...'),
          ],
        ),
      );
    }

    if (errorMessage?.isNotEmpty == true) {
      return _buildErrorDisplay(context, errorMessage!);
    }

    if (result == null) {
      return _buildEmptyState(context);
    }

    if (!result!.isSuccess) {
      return _buildErrorDisplay(context, result!.error ?? 'Unknown error');
    }

    if (result!.data.isEmpty) {
      return _buildNoResultsFound(context);
    }

    return _buildResults(context, result!.data);
  }

  Widget _buildEmptyState(BuildContext context) => _buildPlaceholder(
        context,
        icon: Icons.search,
        iconColor: Theme.of(context).disabledColor,
        title: 'No scraping performed yet',
        titleColor: Theme.of(context).disabledColor,
        message: 'Enter a URL and scraping parameters to get started',
      );

  Widget _buildErrorDisplay(BuildContext context, String error) {
    final scheme = Theme.of(context).colorScheme;

    return _buildPlaceholder(
      context,
      icon: Icons.error_outline,
      iconColor: scheme.error,
      title: 'Scraping Failed',
      titleColor: scheme.error,
      body: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          error,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onErrorContainer),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNoResultsFound(BuildContext context) => _buildPlaceholder(
        context,
        icon: Icons.search_off,
        iconColor: Theme.of(context).disabledColor,
        title: 'No Results Found',
        titleColor: Theme.of(context).disabledColor,
        message: 'Try adjusting your search parameters',
      );

  /// The shared empty / error / no-results state.
  ///
  /// Scrollable rather than a bare [Column]: this sits inside an [Expanded] in
  /// a card, so a short viewport — a small phone, or a tall on-screen keyboard
  /// pushing the card up — left the fixed 64px icon plus two lines of text
  /// with nowhere to go, and Flutter reported a RenderFlex overflow. Wrapping
  /// in a scroll view keeps the content centred when it fits and scrollable
  /// when it does not.
  Widget _buildPlaceholder(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    String? message,
    Widget? body,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          // Take only the height actually needed, so Center can do its job.
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: titleColor),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).disabledColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (body != null) ...[
              const SizedBox(height: 8),
              body,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, List<String> data) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              child: Text('${index + 1}'),
            ),
            title: Text(
              data[index],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Length: ${data[index].length} characters',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy to clipboard',
              onPressed: () => _copyToClipboard(context, data[index]),
            ),
            onTap: () => _showDetailDialog(context, data[index], index + 1),
          ),
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, String text, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Result #$index'),
        content: SingleChildScrollView(
          child: SelectableText(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              _copyToClipboard(context, text);
              Navigator.of(context).pop();
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}
