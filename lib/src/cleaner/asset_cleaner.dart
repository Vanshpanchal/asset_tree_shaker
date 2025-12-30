import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../analyzer/analysis_result.dart';

/// Handles cleaning (deleting) unused assets with safety features.
class AssetCleaner {
  final String projectRoot;

  AssetCleaner({required this.projectRoot});

  /// Cleans unused assets from the analysis result.
  ///
  /// Returns a [CleanResult] with details about deleted and failed deletions.
  Future<CleanResult> clean({
    required AnalysisResult analysisResult,
    bool dryRun = true,
    bool createBackup = true,
    bool removeFromPubspec = false,
  }) async {
    final unusedAssets = analysisResult.unusedAssets;

    if (unusedAssets.isEmpty) {
      return CleanResult(
        deletedAssets: [],
        failedDeletions: [],
        backupFile: null,
        dryRun: dryRun,
      );
    }

    // Create backup if requested
    String? backupPath;
    if (createBackup && !dryRun) {
      backupPath = await _createBackup(unusedAssets);
    }

    final deleted = <DeletedAsset>[];
    final failed = <FailedDeletion>[];

    for (final asset in unusedAssets) {
      final absolutePath = path.join(projectRoot, asset.path);
      final file = File(absolutePath);

      if (dryRun) {
        // In dry run, just record what would be deleted
        deleted.add(DeletedAsset(
          path: asset.path,
          sizeBytes: asset.fileSize ?? 0,
          hash: null,
        ));
      } else {
        try {
          if (await file.exists()) {
            // Calculate hash before deletion for backup purposes
            final bytes = await file.readAsBytes();
            final hash = md5.convert(bytes).toString();

            await file.delete();

            deleted.add(DeletedAsset(
              path: asset.path,
              sizeBytes: asset.fileSize ?? 0,
              hash: hash,
            ));
          }
        } catch (e) {
          failed.add(FailedDeletion(
            path: asset.path,
            reason: e.toString(),
          ));
        }
      }
    }

    // Optionally update pubspec.yaml
    if (removeFromPubspec && !dryRun && deleted.isNotEmpty) {
      await _removeFromPubspec(deleted);
    }

    return CleanResult(
      deletedAssets: deleted,
      failedDeletions: failed,
      backupFile: backupPath,
      dryRun: dryRun,
    );
  }

  /// Creates a backup manifest for the assets to be deleted.
  Future<String> _createBackup(List<AnalyzedAsset> assets) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFileName = '.asset_backup_$timestamp.json';
    final backupPath = path.join(projectRoot, backupFileName);

    final backupData = <Map<String, dynamic>>[];

    for (final asset in assets) {
      final absolutePath = path.join(projectRoot, asset.path);
      final file = File(absolutePath);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final hash = md5.convert(bytes).toString();
        final content = base64Encode(bytes);

        backupData.add({
          'path': asset.path,
          'hash': hash,
          'sizeBytes': asset.fileSize,
          'content': content, // Base64 encoded for small files
        });
      }
    }

    final backup = {
      'timestamp': DateTime.now().toIso8601String(),
      'projectRoot': projectRoot,
      'assets': backupData,
      'restoreCommand':
          'dart run asset_tree_shaker restore --from=$backupFileName',
    };

    final file = File(backupPath);
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(backup));

    return backupPath;
  }

  /// Restores assets from a backup file.
  Future<RestoreResult> restore(String backupFilePath) async {
    final file = File(backupFilePath);

    if (!await file.exists()) {
      throw CleanerException('Backup file not found: $backupFilePath');
    }

    final content = await file.readAsString();
    final backup = jsonDecode(content) as Map<String, dynamic>;
    final assets = backup['assets'] as List;

    final restored = <String>[];
    final failed = <FailedDeletion>[];

    for (final assetData in assets) {
      final assetPath = assetData['path'] as String;
      final contentBase64 = assetData['content'] as String?;

      if (contentBase64 == null) {
        failed.add(FailedDeletion(
          path: assetPath,
          reason: 'No content in backup',
        ));
        continue;
      }

      try {
        final absolutePath = path.join(projectRoot, assetPath);
        final assetFile = File(absolutePath);

        // Create parent directories if needed
        await assetFile.parent.create(recursive: true);

        // Write content
        final bytes = base64Decode(contentBase64);
        await assetFile.writeAsBytes(bytes);

        restored.add(assetPath);
      } catch (e) {
        failed.add(FailedDeletion(
          path: assetPath,
          reason: e.toString(),
        ));
      }
    }

    return RestoreResult(
      restoredAssets: restored,
      failedRestores: failed,
    );
  }

  /// Removes deleted assets from pubspec.yaml.
  Future<void> _removeFromPubspec(List<DeletedAsset> deletedAssets) async {
    final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
    final file = File(pubspecPath);

    if (!await file.exists()) {
      return;
    }

    var content = await file.readAsString();
    final deletedPaths = deletedAssets.map((a) => a.path).toSet();

    // Simple approach: remove lines that exactly match deleted asset paths
    // This is a basic implementation - a more robust approach would parse
    // and rebuild the YAML structure
    final lines = content.split('\n');
    final newLines = <String>[];
    var inAssetsSection = false;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed == 'assets:') {
        inAssetsSection = true;
        newLines.add(line);
        continue;
      }

      if (inAssetsSection) {
        if (trimmed.startsWith('-')) {
          // Check if this is a deleted asset
          final assetPath = trimmed
              .substring(1)
              .trim()
              .replaceAll('"', '')
              .replaceAll("'", '');
          if (deletedPaths.contains(assetPath)) {
            // Skip this line (don't add to newLines)
            continue;
          }
        } else if (!trimmed.startsWith('#') &&
            trimmed.isNotEmpty &&
            !line.startsWith(' ') &&
            !line.startsWith('\t')) {
          // We've exited the assets section
          inAssetsSection = false;
        }
      }

      newLines.add(line);
    }

    await file.writeAsString(newLines.join('\n'));
  }

  /// Previews what would be deleted without actually deleting.
  Future<CleanPreview> preview(AnalysisResult analysisResult) async {
    final unusedAssets = analysisResult.unusedAssets;

    final preview = <AssetPreview>[];
    var totalSize = 0;

    for (final asset in unusedAssets) {
      final absolutePath = path.join(projectRoot, asset.path);
      final file = File(absolutePath);
      final exists = await file.exists();

      preview.add(AssetPreview(
        path: asset.path,
        exists: exists,
        sizeBytes: asset.fileSize ?? 0,
      ));

      totalSize += asset.fileSize ?? 0;
    }

    return CleanPreview(
      assets: preview,
      totalSizeBytes: totalSize,
    );
  }
}

/// Result of a clean operation.
class CleanResult {
  final List<DeletedAsset> deletedAssets;
  final List<FailedDeletion> failedDeletions;
  final String? backupFile;
  final bool dryRun;

  const CleanResult({
    required this.deletedAssets,
    required this.failedDeletions,
    required this.backupFile,
    required this.dryRun,
  });

  bool get hasFailures => failedDeletions.isNotEmpty;

  int get totalDeletedSize =>
      deletedAssets.fold(0, (sum, a) => sum + a.sizeBytes);

  @override
  String toString() {
    if (dryRun) {
      return 'CleanResult (DRY RUN): would delete ${deletedAssets.length} assets';
    }
    return 'CleanResult: deleted ${deletedAssets.length} assets, '
        '${failedDeletions.length} failed';
  }
}

/// Information about a deleted asset.
class DeletedAsset {
  final String path;
  final int sizeBytes;
  final String? hash;

  const DeletedAsset({
    required this.path,
    required this.sizeBytes,
    this.hash,
  });
}

/// Information about a failed deletion.
class FailedDeletion {
  final String path;
  final String reason;

  const FailedDeletion({
    required this.path,
    required this.reason,
  });

  @override
  String toString() => 'Failed to delete $path: $reason';
}

/// Result of a restore operation.
class RestoreResult {
  final List<String> restoredAssets;
  final List<FailedDeletion> failedRestores;

  const RestoreResult({
    required this.restoredAssets,
    required this.failedRestores,
  });

  bool get hasFailures => failedRestores.isNotEmpty;
}

/// Preview of assets that would be deleted.
class CleanPreview {
  final List<AssetPreview> assets;
  final int totalSizeBytes;

  const CleanPreview({
    required this.assets,
    required this.totalSizeBytes,
  });

  String get totalSizeFormatted {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Preview information for a single asset.
class AssetPreview {
  final String path;
  final bool exists;
  final int sizeBytes;

  const AssetPreview({
    required this.path,
    required this.exists,
    required this.sizeBytes,
  });
}

/// Exception thrown by the cleaner.
class CleanerException implements Exception {
  final String message;

  CleanerException(this.message);

  @override
  String toString() => 'CleanerException: $message';
}
