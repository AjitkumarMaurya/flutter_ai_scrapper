import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/scraper_viewmodel.dart';
import 'views/screens/scraper_screen.dart';

void main() {
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
