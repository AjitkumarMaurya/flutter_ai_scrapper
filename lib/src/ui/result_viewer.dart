import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../output/codecs/codecs.dart';
import '../structured/mapper.dart';

/// Interactive multi-view result inspector with field-level provenance badges.
class ResultViewer extends StatelessWidget {
  /// Creates a [ResultViewer].
  const ResultViewer({super.key, required this.result});

  /// The structured harvest result to render.
  final StructuredHarvestResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.table_chart_outlined), text: 'Table'),
                    Tab(icon: Icon(Icons.data_object), text: 'JSON'),
                    Tab(
                      icon: Icon(Icons.description_outlined),
                      text: 'Markdown',
                    ),
                    Tab(icon: Icon(Icons.code), text: 'Raw'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy JSON',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: result.toJsonString(includeProvenance: true),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: TabBarView(
              children: [
                _buildTableView(context),
                _buildCodeView(
                  result.toJsonString(includeProvenance: true),
                  colorScheme,
                ),
                _buildCodeView(result.toMarkdownTable(), colorScheme),
                _buildCodeView(result.toPrettyString(), colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(BuildContext context) {
    final data = result.data;
    final entries = data.entries.toList();

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final fieldName = entry.key;
        final value = entry.value;
        final source = result.coverage.satisfiedFields[fieldName];

        return ListTile(
          dense: true,
          title: Row(
            children: [
              Text(
                fieldName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8.0),
              _buildProvenanceBadge(context, source),
            ],
          ),
          subtitle: Text(
            value?.toString() ?? 'null',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  Widget _buildProvenanceBadge(BuildContext context, ExtractionSource? source) {
    final (label, color) = switch (source) {
      ExtractionSource.jsonLd => ('JSON-LD', Colors.green),
      ExtractionSource.microdata => ('Microdata', Colors.teal),
      ExtractionSource.openGraph => ('OpenGraph', Colors.cyan),
      ExtractionSource.rdfa => ('RDFa', Colors.indigo),
      ExtractionSource.recipe => ('Recipe', Colors.blue),
      ExtractionSource.ai => ('AI', Colors.purple),
      _ => ('Unknown', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCodeView(String code, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          code,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.0),
        ),
      ),
    );
  }
}
