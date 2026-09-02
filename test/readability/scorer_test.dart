import 'dart:io';

import 'package:flutter_ai_scrapper/src/dom/html_document.dart';
import 'package:flutter_ai_scrapper/src/readability/scorer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadabilityScorer', () {
    test('extracts article body and discards chrome on article_news fixture', () {
      final html = File('test/fixtures/article_news/page.html').readAsStringSync();
      final doc = HtmlDocument.parse(html, url: 'https://post.example/2024/11/coastal-towns');

      final article = ReadabilityScorer.extractArticle(doc);

      expect(article.title, 'Coastal towns adapt as tides rise');
      expect(article.byline, 'Priya Raman');
      expect(article.publishDate, '2024-11-02T06:30:00Z');
      expect(article.text, contains('sea-defence work'));
      expect(article.text, contains('Councils along the eastern shoreline'));
      expect(article.text, isNot(contains('Home Climate')));
      expect(article.text, isNot(contains('The Example Post')));
      expect(article.text, isNot(contains('Flood maps redrawn')));
      expect(article.readingTime.inSeconds, greaterThan(0));
    });

    test('extracts article with positive/negative classes in noisy structure', () {
      const html = '''
      <!DOCTYPE html>
      <html><body>
        <div class="nav-bar"><a href="/">Home</a><a href="/about">About</a></div>
        <div class="sidebar"><p>Ad banner promo link here</p></div>
        <div class="main-content article-entry">
          <h1>Clean Energy Transitions</h1>
          <p>Investment in renewable energy reached historic milestones last year, driven by advances in storage technology, expanded solar capacity, and policy initiatives across multiple regions.</p>
          <p>Analysts project continued acceleration over the coming decade, with grid modernisation playing an increasingly pivotal role in ensuring reliable baseload distribution.</p>
        </div>
        <div class="comment-section"><p>User comment: Great article!</p></div>
        <footer class="footer-links"><p>All rights reserved</p></footer>
      </body></html>
      ''';
      final doc = HtmlDocument.parse(html);
      final article = ReadabilityScorer.extractArticle(doc);

      expect(article.text, contains('Investment in renewable energy'));
      expect(article.text, contains('Analysts project continued acceleration'));
      expect(article.text, isNot(contains('Ad banner')));
      expect(article.text, isNot(contains('User comment')));
      expect(article.text, isNot(contains('All rights reserved')));
    });
  });
}
