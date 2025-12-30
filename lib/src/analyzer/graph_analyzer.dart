import '../config/config.dart';
import '../discovery/asset_discovery.dart';
import '../scanner/ast_visitor.dart';
import '../scanner/usage_scanner.dart';
import '../utils/pattern_matcher.dart';
import 'analysis_result.dart';

/// Analyzes asset usage by comparing declared assets against found usages.
class GraphAnalyzer {
  final AssetTreeShakerConfig config;
  final PatternMatcher _patternMatcher;

  GraphAnalyzer({required this.config})
      : _patternMatcher = PatternMatcher(
          excludePatterns: config.excludePatterns,
          dynamicPatterns: config.dynamicPatterns,
        );

  /// Analyzes asset usage and produces a complete result.
  AnalysisResult analyze({
    required Set<DeclaredAsset> declaredAssets,
    required UsageScanResult scanResult,
    required String projectRoot,
  }) {
    final analyzedAssets = <AnalyzedAsset>[];
    final warnings = <DynamicUsageWarning>[];

    // Build reference map for quick lookups
    final referenceMap = _buildReferenceMap(scanResult.allReferences);

    // Analyze each declared asset
    for (final declared in declaredAssets) {
      final analyzed = _analyzeAsset(
        declared: declared,
        scanResult: scanResult,
        referenceMap: referenceMap,
      );
      analyzedAssets.add(analyzed);
    }

    // Generate warnings for dynamic patterns
    warnings.addAll(_generateDynamicWarnings(
      scanResult.dynamicReferences,
      declaredAssets,
    ));

    // Sort assets by status (unused first, then by path)
    analyzedAssets.sort((a, b) {
      final statusCompare =
          _statusPriority(a.status) - _statusPriority(b.status);
      if (statusCompare != 0) return statusCompare;
      return a.path.compareTo(b.path);
    });

    // Calculate summary
    final summary = _calculateSummary(analyzedAssets);

    return AnalysisResult(
      assets: analyzedAssets,
      warnings: warnings,
      summary: summary,
      timestamp: DateTime.now(),
      projectRoot: projectRoot,
      filesScanned: scanResult.scannedFiles.length,
      errors: scanResult.errors.map((e) => e.toString()).toList(),
    );
  }

  /// Analyzes a single asset.
  AnalyzedAsset _analyzeAsset({
    required DeclaredAsset declared,
    required UsageScanResult scanResult,
    required Map<String, List<AssetReference>> referenceMap,
  }) {
    final path = declared.normalizedPath;

    // Check if file exists
    if (declared.absolutePath == null) {
      return AnalyzedAsset(
        path: path,
        status: AssetStatus.missing,
        originalDeclaration: declared.originalDeclaration,
      );
    }

    // Check if directly used
    final references = referenceMap[path] ?? [];
    if (references.isNotEmpty) {
      return AnalyzedAsset(
        path: path,
        status: AssetStatus.used,
        references: references,
        fileSize: declared.fileSize,
        originalDeclaration: declared.originalDeclaration,
      );
    }

    // Check if marked with annotation
    if (scanResult.annotatedAssets.contains(path)) {
      return AnalyzedAsset(
        path: path,
        status: AssetStatus.annotated,
        fileSize: declared.fileSize,
        originalDeclaration: declared.originalDeclaration,
      );
    }

    // Check if whitelisted by config
    if (_patternMatcher.matchesExcludePattern(path)) {
      return AnalyzedAsset(
        path: path,
        status: AssetStatus.whitelisted,
        matchedPattern: _patternMatcher.getMatchingExcludePattern(path),
        fileSize: declared.fileSize,
        originalDeclaration: declared.originalDeclaration,
      );
    }

    // Check if matches a configured dynamic pattern
    if (_patternMatcher.matchesDynamicPattern(path)) {
      return AnalyzedAsset(
        path: path,
        status: AssetStatus.dynamicMatch,
        matchedPattern: _patternMatcher.getMatchingDynamicPattern(path),
        fileSize: declared.fileSize,
        originalDeclaration: declared.originalDeclaration,
      );
    }

    // Check if matches an inferred dynamic pattern from code
    for (final dynamicRef in scanResult.dynamicReferences) {
      if (_matchesDynamicReference(path, dynamicRef)) {
        return AnalyzedAsset(
          path: path,
          status: AssetStatus.dynamicMatch,
          matchedPattern: dynamicRef.inferredPattern,
          fileSize: declared.fileSize,
          originalDeclaration: declared.originalDeclaration,
        );
      }
    }

    // Asset is unused
    return AnalyzedAsset(
      path: path,
      status: AssetStatus.unused,
      fileSize: declared.fileSize,
      originalDeclaration: declared.originalDeclaration,
    );
  }

  /// Builds a map of asset paths to their references.
  Map<String, List<AssetReference>> _buildReferenceMap(
    List<AssetReference> references,
  ) {
    final map = <String, List<AssetReference>>{};
    for (final ref in references) {
      final path = _normalizePath(ref.assetPath);
      map.putIfAbsent(path, () => []).add(ref);
    }
    return map;
  }

  /// Checks if an asset path matches a dynamic reference pattern.
  bool _matchesDynamicReference(String assetPath, DynamicAssetReference ref) {
    // Simple prefix matching
    if (!assetPath.startsWith(ref.staticPrefix)) {
      return false;
    }

    // If there's a suffix, check it too
    if (ref.staticSuffix != null && !assetPath.endsWith(ref.staticSuffix!)) {
      return false;
    }

    return true;
  }

  /// Generates warnings for dynamic patterns found in code.
  List<DynamicUsageWarning> _generateDynamicWarnings(
    Set<DynamicAssetReference> dynamicReferences,
    Set<DeclaredAsset> declaredAssets,
  ) {
    final warnings = <DynamicUsageWarning>[];

    for (final ref in dynamicReferences) {
      // Find assets that might match this pattern
      final affected = declaredAssets
          .where((a) => _matchesDynamicReference(a.normalizedPath, ref))
          .map((a) => a.normalizedPath)
          .toList();

      if (affected.isNotEmpty) {
        warnings.add(DynamicUsageWarning(
          reference: ref,
          potentiallyAffectedAssets: affected,
          suggestedConfig: 'dynamic_patterns:\n  - "${ref.inferredPattern}"',
        ));
      }
    }

    return warnings;
  }

  /// Calculates summary statistics.
  AnalysisSummary _calculateSummary(List<AnalyzedAsset> assets) {
    var totalSize = 0;
    var unusedSize = 0;
    var used = 0;
    var unused = 0;
    var whitelisted = 0;
    var dynamicMatch = 0;
    var annotated = 0;
    var missing = 0;

    for (final asset in assets) {
      final size = asset.fileSize ?? 0;
      totalSize += size;

      switch (asset.status) {
        case AssetStatus.used:
          used++;
          break;
        case AssetStatus.unused:
          unused++;
          unusedSize += size;
          break;
        case AssetStatus.whitelisted:
          whitelisted++;
          break;
        case AssetStatus.dynamicMatch:
          dynamicMatch++;
          break;
        case AssetStatus.annotated:
          annotated++;
          break;
        case AssetStatus.missing:
          missing++;
          break;
      }
    }

    return AnalysisSummary(
      totalAssets: assets.length,
      usedAssets: used,
      unusedAssets: unused,
      whitelistedAssets: whitelisted,
      dynamicMatchAssets: dynamicMatch,
      annotatedAssets: annotated,
      missingAssets: missing,
      totalSizeBytes: totalSize,
      unusedSizeBytes: unusedSize,
    );
  }

  /// Gets priority for status sorting (lower = first).
  int _statusPriority(AssetStatus status) {
    switch (status) {
      case AssetStatus.unused:
        return 0;
      case AssetStatus.missing:
        return 1;
      case AssetStatus.dynamicMatch:
        return 2;
      case AssetStatus.whitelisted:
        return 3;
      case AssetStatus.annotated:
        return 4;
      case AssetStatus.used:
        return 5;
    }
  }

  /// Normalizes a path string.
  String _normalizePath(String p) {
    var normalized = p.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }
}
