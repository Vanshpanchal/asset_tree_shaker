import 'package:test/test.dart';

import 'package:asset_tree_shaker/src/config/config.dart';

void main() {
  group('AssetTreeShakerConfig', () {
    test('creates with default values', () {
      const config = AssetTreeShakerConfig();

      expect(config.scanPaths, equals(['lib/']));
      expect(config.excludePatterns, isEmpty);
      expect(config.strictMode, isFalse);
      expect(config.generateReport, isTrue);
      expect(config.reportFormat, equals(ReportFormat.markdown));
    });

    test('creates with custom values', () {
      const config = AssetTreeShakerConfig(
        scanPaths: ['lib/', 'src/'],
        excludePatterns: ['assets/generated/**'],
        strictMode: true,
        reportFormat: ReportFormat.json,
      );

      expect(config.scanPaths, equals(['lib/', 'src/']));
      expect(config.excludePatterns, equals(['assets/generated/**']));
      expect(config.strictMode, isTrue);
      expect(config.reportFormat, equals(ReportFormat.json));
    });

    test('factory defaults() creates default config', () {
      final config = AssetTreeShakerConfig.defaults();

      expect(config.scanPaths, equals(['lib/']));
      expect(config.strictMode, isFalse);
    });

    test('factory strict() creates strict config', () {
      final config = AssetTreeShakerConfig.strict();

      expect(config.strictMode, isTrue);
      expect(config.includeTests, isTrue);
      expect(config.reportFormat, equals(ReportFormat.json));
    });

    test('copyWith creates modified copy', () {
      const original = AssetTreeShakerConfig(
        strictMode: false,
        scanPaths: ['lib/'],
      );

      final modified = original.copyWith(
        strictMode: true,
        scanPaths: ['lib/', 'test/'],
      );

      expect(original.strictMode, isFalse);
      expect(modified.strictMode, isTrue);
      expect(original.scanPaths, equals(['lib/']));
      expect(modified.scanPaths, equals(['lib/', 'test/']));
    });

    test('equality works correctly', () {
      const config1 = AssetTreeShakerConfig(
        scanPaths: ['lib/'],
        strictMode: true,
      );
      const config2 = AssetTreeShakerConfig(
        scanPaths: ['lib/'],
        strictMode: true,
      );
      const config3 = AssetTreeShakerConfig(
        scanPaths: ['lib/'],
        strictMode: false,
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });

  group('ReportFormat', () {
    test('extension returns correct file extension', () {
      expect(ReportFormat.markdown.extension, equals('.md'));
      expect(ReportFormat.json.extension, equals('.json'));
      expect(ReportFormat.html.extension, equals('.html'));
    });

    test('mimeType returns correct MIME type', () {
      expect(ReportFormat.markdown.mimeType, equals('text/markdown'));
      expect(ReportFormat.json.mimeType, equals('application/json'));
      expect(ReportFormat.html.mimeType, equals('text/html'));
    });

    test('fromString parses format strings', () {
      expect(ReportFormatExtension.fromString('markdown'),
          equals(ReportFormat.markdown));
      expect(ReportFormatExtension.fromString('md'),
          equals(ReportFormat.markdown));
      expect(
          ReportFormatExtension.fromString('json'), equals(ReportFormat.json));
      expect(
          ReportFormatExtension.fromString('html'), equals(ReportFormat.html));
      expect(
          ReportFormatExtension.fromString('JSON'), equals(ReportFormat.json));
    });

    test('fromString throws on unknown format', () {
      expect(
        () => ReportFormatExtension.fromString('xml'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
