import '../scanner/ast_visitor.dart';

/// Categorization of an asset's usage status.
enum AssetStatus {
  /// Asset is directly referenced in code.
  used,

  /// Asset has no references found.
  unused,

  /// Asset is whitelisted via configuration.
  whitelisted,

  /// Asset matches a dynamic pattern.
  dynamicMatch,

  /// Asset is marked with a keep annotation.
  annotated,

  /// Asset declaration exists but file is missing.
  missing,
}

/// Information about a single analyzed asset.
class AnalyzedAsset {
  /// The normalized asset path.
  final String path;

  /// The status of the asset.
  final AssetStatus status;

  /// References to this asset in code (if any).
  final List<AssetReference> references;

  /// The pattern that matched (for dynamic matches).
  final String? matchedPattern;

  /// File size in bytes (if known).
  final int? fileSize;

  /// Original pubspec declaration.
  final String? originalDeclaration;

  const AnalyzedAsset({
    required this.path,
    required this.status,
    this.references = const [],
    this.matchedPattern,
    this.fileSize,
    this.originalDeclaration,
  });

  /// Whether this asset should be considered safe to delete.
  bool get isSafeToDelete => status == AssetStatus.unused;

  /// Whether this asset is protected from deletion.
  bool get isProtected =>
      status == AssetStatus.used ||
      status == AssetStatus.whitelisted ||
      status == AssetStatus.dynamicMatch ||
      status == AssetStatus.annotated;

  @override
  String toString() => 'AnalyzedAsset($path: $status)';
}

/// Complete result of analyzing asset usage.
class AnalysisResult {
  /// All analyzed assets with their status.
  final List<AnalyzedAsset> assets;

  /// Dynamic usage warnings that require attention.
  final List<DynamicUsageWarning> warnings;

  /// Summary statistics.
  final AnalysisSummary summary;

  /// Timestamp of the analysis.
  final DateTime timestamp;

  /// Project root path.
  final String projectRoot;

  /// Number of files scanned.
  final int filesScanned;

  /// Errors encountered during analysis.
  final List<String> errors;

  const AnalysisResult({
    required this.assets,
    required this.warnings,
    required this.summary,
    required this.timestamp,
    required this.projectRoot,
    required this.filesScanned,
    this.errors = const [],
  });

  /// Gets assets by status.
  List<AnalyzedAsset> byStatus(AssetStatus status) =>
      assets.where((a) => a.status == status).toList();

  /// Gets all unused assets.
  List<AnalyzedAsset> get unusedAssets => byStatus(AssetStatus.unused);

  /// Gets all used assets.
  List<AnalyzedAsset> get usedAssets => byStatus(AssetStatus.used);

  /// Gets all whitelisted assets.
  List<AnalyzedAsset> get whitelistedAssets =>
      byStatus(AssetStatus.whitelisted);

  /// Gets all dynamic match assets.
  List<AnalyzedAsset> get dynamicMatchAssets =>
      byStatus(AssetStatus.dynamicMatch);

  /// Gets all annotated assets.
  List<AnalyzedAsset> get annotatedAssets => byStatus(AssetStatus.annotated);

  /// Gets all missing assets.
  List<AnalyzedAsset> get missingAssets => byStatus(AssetStatus.missing);

  /// Whether there are any unused assets.
  bool get hasUnusedAssets => unusedAssets.isNotEmpty;

  /// Whether the analysis passed (no unused assets in strict mode).
  bool get passed => !hasUnusedAssets;

  /// Total size of unused assets.
  int get unusedAssetsSize =>
      unusedAssets.fold<int>(0, (sum, a) => sum + (a.fileSize ?? 0));
}

/// Summary statistics of the analysis.
class AnalysisSummary {
  final int totalAssets;
  final int usedAssets;
  final int unusedAssets;
  final int whitelistedAssets;
  final int dynamicMatchAssets;
  final int annotatedAssets;
  final int missingAssets;
  final int totalSizeBytes;
  final int unusedSizeBytes;

  const AnalysisSummary({
    required this.totalAssets,
    required this.usedAssets,
    required this.unusedAssets,
    required this.whitelistedAssets,
    required this.dynamicMatchAssets,
    required this.annotatedAssets,
    required this.missingAssets,
    required this.totalSizeBytes,
    required this.unusedSizeBytes,
  });

  /// Percentage of assets that are unused.
  double get unusedPercentage =>
      totalAssets > 0 ? (unusedAssets / totalAssets) * 100 : 0;

  /// Percentage of size that is unused.
  double get unusedSizePercentage =>
      totalSizeBytes > 0 ? (unusedSizeBytes / totalSizeBytes) * 100 : 0;

  /// Human-readable unused size.
  String get unusedSizeFormatted => _formatBytes(unusedSizeBytes);

  /// Human-readable total size.
  String get totalSizeFormatted => _formatBytes(totalSizeBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return 'AnalysisSummary('
        'total: $totalAssets, '
        'used: $usedAssets, '
        'unused: $unusedAssets, '
        'whitelisted: $whitelistedAssets, '
        'dynamicMatch: $dynamicMatchAssets, '
        'annotated: $annotatedAssets)';
  }
}

/// Warning about dynamic asset usage.
class DynamicUsageWarning {
  /// The dynamic reference that triggered this warning.
  final DynamicAssetReference reference;

  /// Assets that might be matched by this pattern.
  final List<String> potentiallyAffectedAssets;

  /// Suggested configuration to add.
  final String suggestedConfig;

  const DynamicUsageWarning({
    required this.reference,
    required this.potentiallyAffectedAssets,
    required this.suggestedConfig,
  });

  @override
  String toString() =>
      'DynamicUsageWarning(${reference.inferredPattern}): ${potentiallyAffectedAssets.length} potentially affected assets';
}
