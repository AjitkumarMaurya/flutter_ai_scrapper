/// Flutter Scrapper - A lightweight HTML scraper designed specifically for Flutter mobile (Android/iOS) apps.
///
/// This library provides a simple way to fetch and parse text content from public websites
/// without requiring a backend or heavy dependencies. It works 100% on-device and is
/// optimized for mobile platforms only.
library;

// Core scraping functionality
export 'flutter_mobile_scraper.dart';

// Configuration
export 'config/scraper_config.dart';

// Exceptions
export 'exceptions/scraper_exceptions.dart';

// Smart content extraction
export 'utils/smart_extractor.dart';

// Caching system
export 'utils/cache_manager.dart';

// Content formatting
export 'utils/content_formatter.dart';

// Data models
export 'models/scrape_result.dart';
export 'models/scrape_request.dart';

// ViewModels (for apps that want to use the MVVM pattern)
export 'viewmodels/scraper_viewmodel.dart';
