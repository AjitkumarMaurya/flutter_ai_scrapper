import 'package:flutter/material.dart';
import 'package:flutter_scrapper/mobile_scraper.dart';

void main() {
  runApp(const FlutterScrapperDemo());
}

class FlutterScrapperDemo extends StatelessWidget {
  const FlutterScrapperDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Scrapper Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScrapingDemo(),
    );
  }
}

class ScrapingDemo extends StatefulWidget {
  const ScrapingDemo({super.key});

  @override
  State<ScrapingDemo> createState() => _ScrapingDemoState();
}

class _ScrapingDemoState extends State<ScrapingDemo> {
  final _urlController =
      TextEditingController(text: 'https://httpbin.org/html');
  final _results = <String>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _scrapeWebsite() async {
    if (_urlController.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results.clear();
    });

    try {
      // Create scraper
      final scraper = MobileScraper(
        url: _urlController.text.trim(),
        config: const ScraperConfig(
          timeout: Duration(seconds: 10),
          userAgent: 'Flutter Scrapper Demo/1.0',
        ),
      );

      // Load the webpage with caching
      await scraper.load(useCache: true);

      // Smart content extraction
      final smartContent = scraper.extractSmartContent();

      // Custom extractions
      final headings = scraper.queryAll(tag: 'h1');
      final paragraphs = scraper.queryAll(tag: 'p');

      // Format as markdown
      final markdown = scraper.toMarkdown();
      final wordCount = scraper.getWordCount();
      final readingTime = scraper.estimateReadingTime();

      setState(() {
        _results.addAll([
          '🧠 === SMART EXTRACTION ===',
          '📰 Title: ${smartContent.title ?? "Not found"}',
          '📄 Description: ${smartContent.description ?? "Not found"}',
          '👤 Author: ${smartContent.author ?? "Not found"}',
          '🖼️ Images: ${smartContent.images.length} found',
          '🔗 Links: ${smartContent.links.length} found',
          '📧 Emails: ${smartContent.emails.length} found',
          '💰 Prices: ${smartContent.prices.length} found',
          '',
          '🎯 === CUSTOM EXTRACTION ===',
          '📝 Headings (${headings.length}):',
          ...headings.take(3).map((h) => '  • $h'),
          '',
          '📄 Paragraphs (${paragraphs.length}):',
          ...paragraphs.take(2).map(
              (p) => '  • ${p.length > 100 ? "${p.substring(0, 100)}..." : p}'),
          '',
          '📊 === CONTENT ANALYSIS ===',
          '📖 Word Count: $wordCount',
          '⏱️ Reading Time: ${readingTime.inMinutes} min',
          '',
          '📝 === MARKDOWN PREVIEW ===',
          markdown.length > 300 ? '${markdown.substring(0, 300)}...' : markdown,
        ]);
        _loading = false;
      });

      // Cache stats
      final cacheStats = MobileScraper.getCacheStats();
      _results.add('');
      _results.add('💾 === CACHE STATS ===');
      _results.add('📊 Entries: ${cacheStats.entryCount}');
      _results.add('💾 Size: ${cacheStats.totalSizeMB.toStringAsFixed(2)}MB');

      // Clean up
      scraper.dispose();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Flutter Scrapper Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL Input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '🌐 Website URL',
                border: OutlineInputBorder(),
                hintText: 'https://httpbin.org/html',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),

            // Scrape Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _scrapeWebsite,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Scraping...' : '🚀 Start Scraping'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Results
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _error != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            '❌ Error: $_error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.web, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  '👋 Welcome to Flutter Scrapper!\n\nEnter a URL and tap "Start Scraping" to see the magic ✨',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final result = _results[index];
                              if (result.startsWith('===') ||
                                  result.startsWith('🧠') ||
                                  result.startsWith('🎯') ||
                                  result.startsWith('📊') ||
                                  result.startsWith('📝') ||
                                  result.startsWith('💾')) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    result,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }
                              if (result.isEmpty) {
                                return const SizedBox(height: 8);
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  result,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
