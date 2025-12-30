import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'config.dart';

/// Loads and parses asset_tree_shaker.yaml configuration files.
class ConfigLoader {
  /// Default configuration file name.
  static const String defaultConfigFileName = 'asset_tree_shaker.yaml';

  /// Alternative configuration file names.
  static const List<String> alternativeConfigNames = [
    'asset_tree_shaker.yml',
    '.asset_tree_shaker.yaml',
    '.asset_tree_shaker.yml',
  ];

  final String projectRoot;

  ConfigLoader({required this.projectRoot});

  /// Loads configuration from the project root.
  ///
  /// Returns default configuration if no config file is found.
  Future<AssetTreeShakerConfig> load() async {
    final configFile = await _findConfigFile();

    if (configFile == null) {
      return AssetTreeShakerConfig.defaults();
    }

    return _parseConfigFile(configFile);
  }

  /// Finds the configuration file in the project root.
  Future<File?> _findConfigFile() async {
    // Check default name first
    final defaultPath = path.join(projectRoot, defaultConfigFileName);
    final defaultFile = File(defaultPath);
    if (await defaultFile.exists()) {
      return defaultFile;
    }

    // Check alternative names
    for (final name in alternativeConfigNames) {
      final filePath = path.join(projectRoot, name);
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
    }

    return null;
  }

  /// Parses the configuration file content.
  Future<AssetTreeShakerConfig> _parseConfigFile(File file) async {
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);

      if (yaml == null) {
        return AssetTreeShakerConfig.defaults();
      }

      if (yaml is! Map) {
        throw ConfigurationException(
          'Invalid configuration format: expected a YAML map',
          file.path,
        );
      }

      return _mapToConfig(yaml);
    } on YamlException catch (e) {
      throw ConfigurationException(
        'Failed to parse YAML: ${e.message}',
        file.path,
      );
    }
  }

  /// Converts a YAML map to configuration object.
  AssetTreeShakerConfig _mapToConfig(Map<dynamic, dynamic> yaml) {
    return AssetTreeShakerConfig(
      scanPaths: _parseStringList(yaml['scan_paths']) ?? ['lib/'],
      excludePatterns: _parseStringList(yaml['exclude_patterns']) ?? [],
      keepAnnotations: _parseStringList(yaml['keep_annotations']) ??
          ['KeepAsset', 'KeepAssets', 'PreserveAsset'],
      dynamicPatterns: _parseStringList(yaml['dynamic_patterns']) ?? [],
      strictMode: _parseBool(yaml['strict_mode']) ?? false,
      generateReport: _parseBool(yaml['generate_report']) ?? true,
      reportFormat: _parseReportFormat(yaml['report_format']),
      reportOutputPath: yaml['report_output_path'] as String?,
      assetPrefixes:
          _parseStringList(yaml['asset_prefixes']) ?? ['assets/', 'packages/'],
      includeTests: _parseBool(yaml['include_tests']) ?? false,
      includeGeneratedFiles:
          _parseBool(yaml['include_generated_files']) ?? true,
    );
  }

  /// Parses a YAML list to a string list.
  List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  /// Parses a YAML value to boolean.
  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }

  /// Parses a YAML value to ReportFormat.
  ReportFormat _parseReportFormat(dynamic value) {
    if (value == null) return ReportFormat.markdown;
    if (value is String) {
      try {
        return ReportFormatExtension.fromString(value);
      } catch (_) {
        return ReportFormat.markdown;
      }
    }
    return ReportFormat.markdown;
  }

  /// Creates a default configuration file in the project root.
  Future<File> createDefaultConfig() async {
    final configPath = path.join(projectRoot, defaultConfigFileName);
    final file = File(configPath);

    const content = '''
# Asset Tree Shaker Configuration
# https://github.com/your-org/asset_tree_shaker

# Directories to scan for Dart files (relative to project root)
scan_paths:
  - lib/

# Glob patterns for assets to exclude from analysis
exclude_patterns:
  # - "assets/generated/**"
  # - "assets/placeholders/**"

# Annotation names that mark assets as required (prevents removal)
keep_annotations:
  - KeepAsset
  - KeepAssets
  - PreserveAsset

# Known dynamic asset patterns to whitelist
# Use when assets are loaded dynamically (e.g., 'assets/avatars/\$id.png')
dynamic_patterns:
  # - "assets/avatars/*.png"
  # - "assets/locales/*.json"

# Fail the build if unused assets are found (CI/CD mode)
strict_mode: false

# Generate a report file after analysis
generate_report: true

# Report format: markdown, json, or html
report_format: markdown

# Custom report output path (optional)
# report_output_path: "reports/asset_report.md"

# Additional asset path prefixes to recognize
asset_prefixes:
  - assets/
  - packages/

# Include test directories in scan
include_tests: false

# Scan generated files (.g.dart, .freezed.dart)
include_generated_files: true
''';

    await file.writeAsString(content);
    return file;
  }
}

/// Exception thrown when configuration parsing fails.
class ConfigurationException implements Exception {
  final String message;
  final String? filePath;

  ConfigurationException(this.message, [this.filePath]);

  @override
  String toString() {
    if (filePath != null) {
      return 'ConfigurationException: $message (in $filePath)';
    }
    return 'ConfigurationException: $message';
  }
}
