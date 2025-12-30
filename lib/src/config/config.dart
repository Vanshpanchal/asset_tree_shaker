import 'package:collection/collection.dart';

/// Configuration for asset tree shaker.
class AssetTreeShakerConfig {
  /// Paths to scan for Dart files (relative to project root).
  final List<String> scanPaths;

  /// Glob patterns for assets to exclude from analysis.
  final List<String> excludePatterns;

  /// Annotation names that mark assets as required.
  final List<String> keepAnnotations;

  /// Known dynamic asset patterns to whitelist.
  final List<String> dynamicPatterns;

  /// Whether to fail the build if unused assets are found.
  final bool strictMode;

  /// Whether to generate a report file.
  final bool generateReport;

  /// Report format: markdown, json, or html.
  final ReportFormat reportFormat;

  /// Output path for the report file.
  final String? reportOutputPath;

  /// Additional asset path prefixes to recognize.
  final List<String> assetPrefixes;

  /// Whether to include test directories in scan.
  final bool includeTests;

  /// Whether to scan generated files (.g.dart, .freezed.dart).
  final bool includeGeneratedFiles;

  const AssetTreeShakerConfig({
    this.scanPaths = const ['lib/'],
    this.excludePatterns = const [],
    this.keepAnnotations = const ['KeepAsset', 'KeepAssets', 'PreserveAsset'],
    this.dynamicPatterns = const [],
    this.strictMode = false,
    this.generateReport = true,
    this.reportFormat = ReportFormat.markdown,
    this.reportOutputPath,
    this.assetPrefixes = const ['assets/', 'packages/'],
    this.includeTests = false,
    this.includeGeneratedFiles = true,
  });

  /// Creates a default configuration.
  factory AssetTreeShakerConfig.defaults() {
    return const AssetTreeShakerConfig();
  }

  /// Creates a configuration for strict CI/CD mode.
  factory AssetTreeShakerConfig.strict() {
    return const AssetTreeShakerConfig(
      strictMode: true,
      includeTests: true,
      generateReport: true,
      reportFormat: ReportFormat.json,
    );
  }

  /// Creates a copy with the specified fields replaced.
  AssetTreeShakerConfig copyWith({
    List<String>? scanPaths,
    List<String>? excludePatterns,
    List<String>? keepAnnotations,
    List<String>? dynamicPatterns,
    bool? strictMode,
    bool? generateReport,
    ReportFormat? reportFormat,
    String? reportOutputPath,
    List<String>? assetPrefixes,
    bool? includeTests,
    bool? includeGeneratedFiles,
  }) {
    return AssetTreeShakerConfig(
      scanPaths: scanPaths ?? this.scanPaths,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      keepAnnotations: keepAnnotations ?? this.keepAnnotations,
      dynamicPatterns: dynamicPatterns ?? this.dynamicPatterns,
      strictMode: strictMode ?? this.strictMode,
      generateReport: generateReport ?? this.generateReport,
      reportFormat: reportFormat ?? this.reportFormat,
      reportOutputPath: reportOutputPath ?? this.reportOutputPath,
      assetPrefixes: assetPrefixes ?? this.assetPrefixes,
      includeTests: includeTests ?? this.includeTests,
      includeGeneratedFiles:
          includeGeneratedFiles ?? this.includeGeneratedFiles,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is AssetTreeShakerConfig &&
        listEquals(other.scanPaths, scanPaths) &&
        listEquals(other.excludePatterns, excludePatterns) &&
        listEquals(other.keepAnnotations, keepAnnotations) &&
        listEquals(other.dynamicPatterns, dynamicPatterns) &&
        other.strictMode == strictMode &&
        other.generateReport == generateReport &&
        other.reportFormat == reportFormat &&
        other.reportOutputPath == reportOutputPath &&
        listEquals(other.assetPrefixes, assetPrefixes) &&
        other.includeTests == includeTests &&
        other.includeGeneratedFiles == includeGeneratedFiles;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(scanPaths),
      Object.hashAll(excludePatterns),
      Object.hashAll(keepAnnotations),
      Object.hashAll(dynamicPatterns),
      strictMode,
      generateReport,
      reportFormat,
      reportOutputPath,
      Object.hashAll(assetPrefixes),
      includeTests,
      includeGeneratedFiles,
    );
  }

  @override
  String toString() {
    return 'AssetTreeShakerConfig('
        'scanPaths: $scanPaths, '
        'excludePatterns: $excludePatterns, '
        'strictMode: $strictMode, '
        'reportFormat: $reportFormat)';
  }
}

/// Supported report output formats.
enum ReportFormat {
  markdown,
  json,
  html,
}

/// Extension to parse report format from string.
extension ReportFormatExtension on ReportFormat {
  String get extension {
    switch (this) {
      case ReportFormat.markdown:
        return '.md';
      case ReportFormat.json:
        return '.json';
      case ReportFormat.html:
        return '.html';
    }
  }

  String get mimeType {
    switch (this) {
      case ReportFormat.markdown:
        return 'text/markdown';
      case ReportFormat.json:
        return 'application/json';
      case ReportFormat.html:
        return 'text/html';
    }
  }

  static ReportFormat fromString(String value) {
    switch (value.toLowerCase()) {
      case 'markdown':
      case 'md':
        return ReportFormat.markdown;
      case 'json':
        return ReportFormat.json;
      case 'html':
        return ReportFormat.html;
      default:
        throw ArgumentError('Unknown report format: $value');
    }
  }
}
