import 'package:flutter/material.dart';
import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register on-device inference engines:
  try {
    await FlutterGemma.initialize(
      inferenceEngines: [
        LiteRtLmEngine(),
        MediaPipeEngine(),
      ],
    );
  } catch (e) {
    debugPrint('FlutterGemma initialization note: $e');
  }

  runApp(const ScrapperDemoApp());
}

class ScrapperDemoApp extends StatefulWidget {
  const ScrapperDemoApp({super.key});

  @override
  State<ScrapperDemoApp> createState() => _ScrapperDemoAppState();
}

class _ScrapperDemoAppState extends State<ScrapperDemoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Scrapper 2.0',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: DemoHomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  int _currentTierIndex = 0;
  final ModelManager _modelManager = ModelManager();
  final RecipeStore _recipeStore = RecipeStore();
  late final ProviderChain _chain;

  @override
  void initState() {
    super.initState();
    _chain = ProviderChain(
      providers: [
        GemmaProvider(manager: _modelManager),
        OpenAiProvider(
          baseUrl: 'http://localhost:11434/v1',
          model: 'llama3',
        ),
      ],
      allowCloudEgress: false, // Security default
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter AI Scrapper 2.0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory),
            tooltip: 'On-Device Models',
            onPressed: () => ModelManagerSheet.show(context, manager: _modelManager),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Provider Settings',
            onPressed: () => ProviderSettingsSheet.show(context, chain: _chain),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTierIndex,
        children: [
          // Tier 1: Quick Scrape
          _buildQuickScrapeTab(),
          // Tier 2: Schema Extraction
          _buildSchemaTab(),
          // Tier 3: Ask a Question
          ExtractionConsole(
            provider: _chain,
            recipeStore: _recipeStore,
          ),
          // Tier 4: Recipes
          _buildRecipesTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTierIndex,
        onDestinationSelected: (i) => setState(() => _currentTierIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on),
            label: 'Quick Scrape',
          ),
          NavigationDestination(
            icon: Icon(Icons.schema_outlined),
            selectedIcon: Icon(Icons.schema),
            label: 'Typed Schema',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Ask Page',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat),
            selectedIcon: Icon(Icons.repeat_on),
            label: 'Recipes',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickScrapeTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tier 1: Deterministic Zero-AI Extraction',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Extracts clean readability prose, JSON-LD, OpenGraph, and Microdata without any model tokens or platform weight.',
          ),
          const SizedBox(height: 16.0),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Scrape Sample (Hacker News)'),
            onPressed: () async {
              final page = await AiScrapper.scrape('https://news.ycombinator.com');
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(page.title ?? 'Parsed Page'),
                    content: SingleChildScrollView(
                      child: Text('Word count: ${page.document.select("a").length} links found.'),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tier 2: Typed Schema Extraction',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Maps directly to typed Dart schemas. Harvests structured JSON-LD first for free, falling back to on-device Gemma or cloud providers.',
          ),
          const SizedBox(height: 16.0),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Extract Product Schema'),
            onPressed: () async {
              const html = '''
              <html><head>
                <script type="application/ld+json">
                {"@context": "https://schema.org", "@type": "Product", "name": "Studio Headphones", "offers": {"price": "149.99", "priceCurrency": "USD"}}
                </script>
              </head><body><h1>Studio Headphones</h1></body></html>
              ''';
              final page = AiScrapper.fromHtml(html, url: 'https://shop.example/item');
              final result = page.extract(Schema.object({
                'name': const Field.string(),
                'price': const Field.money(),
              }));

              if (context.mounted) {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => Container(
                    padding: const EdgeInsets.all(16.0),
                    child: ResultViewer(result: result),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tier 4: Site-Level Selector Recipes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Expensive AI judgement runs once per domain to discover CSS selectors. All subsequent pages execute with pure CSS and ZERO inference tokens.',
          ),
          const SizedBox(height: 16.0),
          Text(
            'Cached Recipes: ${_recipeStore.count}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear Recipe Store'),
            onPressed: () => setState(() => _recipeStore.clear()),
          ),
        ],
      ),
    );
  }
}
