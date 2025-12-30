import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as path;

import '../config/config.dart';
import 'ast_visitor.dart';

/// Scans Dart files to find asset references using AST analysis.
class UsageScanner {
  final String projectRoot;
  final AssetTreeShakerConfig config;

  UsageScanner({
    required this.projectRoot,
    required this.config,
  });

  /// Scans all configured directories for asset references.
  Future<UsageScanResult> scan() async {
    final dartFiles = await _collectDartFiles();
    final results = await Future.wait(
      dartFiles.map((file) => _scanFile(file)),
    );

    return results.fold<UsageScanResult>(
      UsageScanResult.empty(),
      (combined, result) => combined.merge(result),
    );
  }

  /// Collects all Dart files to scan based on configuration.
  Future<List<File>> _collectDartFiles() async {
    final files = <File>[];

    for (final scanPath in config.scanPaths) {
      final absolutePath = path.join(projectRoot, scanPath);
      final dir = Directory(absolutePath);

      if (!await dir.exists()) {
        continue;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          // Check if we should include generated files
          if (!config.includeGeneratedFiles && _isGeneratedFile(entity.path)) {
            continue;
          }

          files.add(entity);
        }
      }
    }

    // Optionally include test directory
    if (config.includeTests) {
      final testDir = Directory(path.join(projectRoot, 'test'));
      if (await testDir.exists()) {
        await for (final entity in testDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            if (!config.includeGeneratedFiles &&
                _isGeneratedFile(entity.path)) {
              continue;
            }
            files.add(entity);
          }
        }
      }
    }

    return files;
  }

  /// Checks if a file is a generated file.
  bool _isGeneratedFile(String filePath) {
    final fileName = path.basename(filePath);
    return fileName.endsWith('.g.dart') ||
        fileName.endsWith('.freezed.dart') ||
        fileName.endsWith('.gr.dart') ||
        fileName.endsWith('.mocks.dart');
  }

  /// Scans a single Dart file for asset references.
  Future<UsageScanResult> _scanFile(File file) async {
    try {
      final content = await file.readAsString();
      final relativePath = path.relative(file.path, from: projectRoot);

      // Parse the Dart file
      final parseResult = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );

      // Visit the AST
      final visitor = AssetReferenceVisitor(
        sourceFile: relativePath,
        assetPrefixes: config.assetPrefixes,
        keepAnnotations: config.keepAnnotations,
      );

      parseResult.unit.visitChildren(visitor);

      final visitorResult = visitor.result;

      return UsageScanResult(
        staticAssets: visitorResult.staticAssets,
        dynamicReferences: visitorResult.dynamicReferences,
        annotatedAssets: visitorResult.annotatedAssets,
        allReferences: visitorResult.allReferences,
        scannedFiles: {relativePath},
        errors: const [],
      );
    } catch (e) {
      final relativePath = path.relative(file.path, from: projectRoot);
      return UsageScanResult(
        staticAssets: const {},
        dynamicReferences: const {},
        annotatedAssets: const {},
        allReferences: const [],
        scannedFiles: {relativePath},
        errors: [ScanError(file: relativePath, message: e.toString())],
      );
    }
  }

  /// Scans specific files only (useful for incremental analysis).
  Future<UsageScanResult> scanFiles(List<String> filePaths) async {
    final files = filePaths.map((p) {
      if (path.isAbsolute(p)) {
        return File(p);
      }
      return File(path.join(projectRoot, p));
    }).toList();

    final results = await Future.wait(
      files.where((f) => f.existsSync()).map((file) => _scanFile(file)),
    );

    return results.fold<UsageScanResult>(
      UsageScanResult.empty(),
      (combined, result) => combined.merge(result),
    );
  }
}

/// Result of scanning for asset usages.
class UsageScanResult {
  /// Static asset paths found in code.
  final Set<String> staticAssets;

  /// Dynamic asset references that couldn't be fully resolved.
  final Set<DynamicAssetReference> dynamicReferences;

  /// Assets marked with keep annotations.
  final Set<String> annotatedAssets;

  /// All references with source location information.
  final List<AssetReference> allReferences;

  /// Files that were scanned.
  final Set<String> scannedFiles;

  /// Errors encountered during scanning.
  final List<ScanError> errors;

  const UsageScanResult({
    required this.staticAssets,
    required this.dynamicReferences,
    required this.annotatedAssets,
    required this.allReferences,
    required this.scannedFiles,
    required this.errors,
  });

  /// Creates an empty result.
  factory UsageScanResult.empty() {
    return const UsageScanResult(
      staticAssets: {},
      dynamicReferences: {},
      annotatedAssets: {},
      allReferences: [],
      scannedFiles: {},
      errors: [],
    );
  }

  /// Merges two scan results.
  UsageScanResult merge(UsageScanResult other) {
    return UsageScanResult(
      staticAssets: {...staticAssets, ...other.staticAssets},
      dynamicReferences: {...dynamicReferences, ...other.dynamicReferences},
      annotatedAssets: {...annotatedAssets, ...other.annotatedAssets},
      allReferences: [...allReferences, ...other.allReferences],
      scannedFiles: {...scannedFiles, ...other.scannedFiles},
      errors: [...errors, ...other.errors],
    );
  }

  /// Gets all used asset paths (static + annotated).
  Set<String> get allUsedAssets => {...staticAssets, ...annotatedAssets};

  /// Gets all inferred dynamic patterns.
  Set<String> get dynamicPatterns =>
      dynamicReferences.map((r) => r.inferredPattern).toSet();

  @override
  String toString() {
    return 'UsageScanResult('
        'staticAssets: ${staticAssets.length}, '
        'dynamicReferences: ${dynamicReferences.length}, '
        'annotatedAssets: ${annotatedAssets.length}, '
        'scannedFiles: ${scannedFiles.length}, '
        'errors: ${errors.length})';
  }
}

/// Error encountered during file scanning.
class ScanError {
  final String file;
  final String message;

  const ScanError({required this.file, required this.message});

  @override
  String toString() => 'ScanError($file): $message';
}
