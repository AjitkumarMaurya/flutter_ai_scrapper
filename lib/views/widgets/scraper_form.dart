import 'package:flutter/material.dart';

/// Reusable form widget for scraping input parameters
class ScraperForm extends StatefulWidget {
  final VoidCallback? onTagScrape;
  final VoidCallback? onRegexScrape;
  final TextEditingController urlController;
  final TextEditingController tagController;
  final TextEditingController classController;
  final TextEditingController regexController;
  final bool isLoading;

  const ScraperForm({
    super.key,
    required this.onTagScrape,
    required this.onRegexScrape,
    required this.urlController,
    required this.tagController,
    required this.classController,
    required this.regexController,
    this.isLoading = false,
  });

  @override
  State<ScraperForm> createState() => _ScraperFormState();
}

class _ScraperFormState extends State<ScraperForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // URL Input
        _buildUrlInput(),
        const SizedBox(height: 16),

        // Tag-based scraping section
        _buildTagBasedSection(),
        const SizedBox(height: 16),

        // Regex-based scraping section
        _buildRegexBasedSection(),
      ],
    );
  }

  Widget _buildUrlInput() {
    return TextField(
      controller: widget.urlController,
      decoration: const InputDecoration(
        labelText: 'URL to scrape',
        border: OutlineInputBorder(),
        hintText: 'https://example.com',
        prefixIcon: Icon(Icons.link),
      ),
      keyboardType: TextInputType.url,
      enabled: !widget.isLoading,
    );
  }

  Widget _buildTagBasedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Tag-based Scraping',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.tagController,
                    decoration: const InputDecoration(
                      labelText: 'HTML Tag *',
                      border: OutlineInputBorder(),
                      hintText: 'h1, p, div',
                    ),
                    enabled: !widget.isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.classController,
                    decoration: const InputDecoration(
                      labelText: 'CSS Class (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'headline',
                    ),
                    enabled: !widget.isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isLoading ? null : widget.onTagScrape,
                icon: widget.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Scrape by Tag'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegexBasedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pattern, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Regex-based Scraping',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.regexController,
              decoration: const InputDecoration(
                labelText: 'Regex Pattern *',
                border: OutlineInputBorder(),
                hintText: r'<title>(.*?)</title>',
              ),
              enabled: !widget.isLoading,
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isLoading ? null : widget.onRegexScrape,
                icon: widget.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Scrape by Regex'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
