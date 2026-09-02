import 'package:flutter/foundation.dart';
import '../flutter_mobile_scraper.dart';
import '../models/scrape_request.dart';
import '../models/scrape_result.dart';

/// ViewModel for managing web scraping operations and UI state
class ScraperViewModel extends ChangeNotifier {
  // Private fields
  MobileScraper? _currentScraper;
  bool _isLoading = false;
  String _errorMessage = '';
  List<ScrapeResult> _scrapeHistory = [];
  ScrapeResult? _currentResult;

  // Getters for UI state
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<ScrapeResult> get scrapeHistory => List.unmodifiable(_scrapeHistory);
  ScrapeResult? get currentResult => _currentResult;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get hasResults =>
      _currentResult?.isSuccess == true && _currentResult!.data.isNotEmpty;

  /// Performs a web scraping operation based on the provided request
  Future<void> performScrape(ScrapeRequest request) async {
    _setLoading(true);
    _clearError();

    try {
      // Create new scraper instance
      _currentScraper = MobileScraper(url: request.url);

      // Load HTML content
      await _currentScraper!.load();

      List<String> results;
      ScrapeType scrapeType;

      // Execute scraping based on request type
      switch (request.type) {
        case ScrapeRequestType.tagBased:
          final tagReq = request.tagRequest!;
          results = _currentScraper!.queryAll(
            tag: tagReq.tag,
            className: tagReq.className,
            id: tagReq.id,
          );
          scrapeType = ScrapeType.tagBased;
          break;

        case ScrapeRequestType.regexBased:
          final regexReq = request.regexRequest!;
          results = _currentScraper!.queryWithRegex(
            pattern: regexReq.pattern,
            group: regexReq.group,
          );
          scrapeType = ScrapeType.regexBased;
          break;
      }

      // Create successful result
      final result = ScrapeResult.success(
        data: results,
        url: request.url,
        type: scrapeType,
      );

      _setCurrentResult(result);
      _addToHistory(result);
    } catch (e) {
      // Create failure result
      final result = ScrapeResult.failure(
        url: request.url,
        error: e.toString(),
        type: request.type == ScrapeRequestType.tagBased
            ? ScrapeType.tagBased
            : ScrapeType.regexBased,
      );

      _setError(e.toString());
      _setCurrentResult(result);
      _addToHistory(result);
    } finally {
      _setLoading(false);
    }
  }

  /// Performs tag-based scraping
  Future<void> scrapeByTag({
    required String url,
    required String tag,
    String? className,
    String? id,
  }) async {
    final request = ScrapeRequest.tagBased(
      url: url,
      tag: tag,
      className: className,
      id: id,
    );
    await performScrape(request);
  }

  /// Performs regex-based scraping
  Future<void> scrapeByRegex({
    required String url,
    required String pattern,
    int group = 1,
  }) async {
    final request = ScrapeRequest.regexBased(
      url: url,
      pattern: pattern,
      group: group,
    );
    await performScrape(request);
  }

  /// Clears the current results and error state
  void clearResults() {
    _currentResult = null;
    _clearError();
    notifyListeners();
  }

  /// Clears the scraping history
  void clearHistory() {
    _scrapeHistory.clear();
    notifyListeners();
  }

  /// Gets the raw HTML content from the current scraper
  String? getRawHtml() {
    return _currentScraper?.rawHtml;
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void _setCurrentResult(ScrapeResult result) {
    _currentResult = result;
    notifyListeners();
  }

  void _addToHistory(ScrapeResult result) {
    _scrapeHistory.insert(0, result); // Add to beginning for recent-first order

    // Limit history to 50 items to prevent memory issues
    if (_scrapeHistory.length > 50) {
      _scrapeHistory = _scrapeHistory.take(50).toList();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _currentScraper = null;
    super.dispose();
  }
}
