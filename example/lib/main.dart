import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:provider/provider.dart';
import 'viewmodels/scraper_viewmodel.dart';
import 'views/screens/scraper_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register on-device inference engines:
  // - LiteRtLmEngine (.litertlm): arm64-v8a devices
  // - MediaPipeEngine (.task): x86_64 emulator and armeabi-v7a
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mobile Scraper Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (context) => ScraperViewModel(),
        child: const ScraperScreen(),
      ),
    );
  }
}
