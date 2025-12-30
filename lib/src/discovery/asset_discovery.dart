import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Represents a declared asset from pubspec.yaml.
class DeclaredAsset {
  /// Normalized path to the asset.
  final String normalizedPath;

  /// Original declaration from pubspec.yaml.
  final String originalDeclaration;

  /// Whether this was declared as a directory.
  final bool isDirectory;

  /// Whether the declaration contains a glob pattern.
  final bool isGlob;

  /// The absolute file path (resolved).
  final String? absolutePath;

  /// File size in bytes (if resolved).
  final int? fileSize;

  const DeclaredAsset({
    required this.normalizedPath,
    required this.originalDeclaration,
    this.isDirectory = false,
    this.isGlob = false,
    this.absolutePath,
    this.fileSize,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeclaredAsset &&
        other.normalizedPath == normalizedPath &&
        other.originalDeclaration == originalDeclaration;
  }

  @override
  int get hashCode => Object.hash(normalizedPath, originalDeclaration);

  @override
  String toString() => 'DeclaredAsset($normalizedPath)';
}

/// Discovers and enumerates assets declared in pubspec.yaml.
class AssetDiscovery {
  final String projectRoot;

  AssetDiscovery({required this.projectRoot});

  /// Discovers all assets declared in pubspec.yaml.
  ///
  /// Returns a set of [DeclaredAsset] objects representing all concrete
  /// asset files found based on the declarations.
  Future<Set<DeclaredAsset>> discoverAssets() async {
    final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);

    if (!await pubspecFile.exists()) {
      throw AssetDiscoveryException(
        'pubspec.yaml not found at $pubspecPath',
      );
    }

    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content);

    if (yaml == null || yaml is! Map) {
      throw AssetDiscoveryException('Invalid pubspec.yaml format');
    }

    return _extractAssets(yaml);
  }

  /// Extracts assets from the parsed pubspec.yaml.
  Future<Set<DeclaredAsset>> _extractAssets(Map<dynamic, dynamic> yaml) async {
    final assets = <DeclaredAsset>{};

    // Get flutter section
    final flutter = yaml['flutter'];
    if (flutter == null || flutter is! Map) {
      return assets;
    }

    // Get assets list
    final assetList = flutter['assets'];
    if (assetList == null) {
      return assets;
    }

    if (assetList is! List) {
      throw AssetDiscoveryException(
        'flutter.assets must be a list in pubspec.yaml',
      );
    }

    // Process each asset declaration
    for (final declaration in assetList) {
      final declStr = declaration.toString();
      final resolvedAssets = await _resolveAssetDeclaration(declStr);
      assets.addAll(resolvedAssets);
    }

    return assets;
  }

  /// Resolves a single asset declaration to concrete files.
  ///
  /// Handles:
  /// - Direct file paths: 'assets/images/logo.png'
  /// - Directory paths: 'assets/images/' (ending with /)
  /// - Glob patterns: 'assets/icons/*.svg'
  Future<Set<DeclaredAsset>> _resolveAssetDeclaration(
      String declaration) async {
    final assets = <DeclaredAsset>{};
    final normalizedDecl = _normalizePath(declaration);

    // Check if it's a directory declaration (ends with /)
    if (normalizedDecl.endsWith('/')) {
      final dirAssets =
          await _resolveDirectoryAssets(normalizedDecl, declaration);
      assets.addAll(dirAssets);
      return assets;
    }

    // Check if it contains glob patterns
    if (_containsGlobPattern(normalizedDecl)) {
      final globAssets = await _resolveGlobAssets(normalizedDecl, declaration);
      assets.addAll(globAssets);
      return assets;
    }

    // Direct file path
    final absolutePath = path.join(projectRoot, normalizedDecl);
    final file = File(absolutePath);

    if (await file.exists()) {
      final stat = await file.stat();
      assets.add(DeclaredAsset(
        normalizedPath: normalizedDecl,
        originalDeclaration: declaration,
        absolutePath: absolutePath,
        fileSize: stat.size,
      ));
    } else {
      // Asset declared but file doesn't exist - still track it
      assets.add(DeclaredAsset(
        normalizedPath: normalizedDecl,
        originalDeclaration: declaration,
      ));
    }

    return assets;
  }

  /// Resolves directory declaration to all files within.
  Future<Set<DeclaredAsset>> _resolveDirectoryAssets(
    String dirPath,
    String originalDeclaration,
  ) async {
    final assets = <DeclaredAsset>{};
    final absoluteDir = path.join(projectRoot, dirPath);
    final dir = Directory(absoluteDir);

    if (!await dir.exists()) {
      return assets;
    }

    await for (final entity in dir.list(recursive: false)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: projectRoot);
        final normalizedPath = _normalizePath(relativePath);
        final stat = await entity.stat();

        assets.add(DeclaredAsset(
          normalizedPath: normalizedPath,
          originalDeclaration: originalDeclaration,
          isDirectory: true,
          absolutePath: entity.path,
          fileSize: stat.size,
        ));
      }
    }

    return assets;
  }

  /// Resolves glob pattern to matching files.
  Future<Set<DeclaredAsset>> _resolveGlobAssets(
    String pattern,
    String originalDeclaration,
  ) async {
    final assets = <DeclaredAsset>{};
    final glob = Glob(pattern);

    try {
      await for (final entity in glob.list(root: projectRoot)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: projectRoot);
          final normalizedPath = _normalizePath(relativePath);
          final stat = await entity.stat();

          assets.add(DeclaredAsset(
            normalizedPath: normalizedPath,
            originalDeclaration: originalDeclaration,
            isGlob: true,
            absolutePath: entity.path,
            fileSize: stat.size,
          ));
        }
      }
    } catch (e) {
      // Glob pattern might be invalid or no matches
    }

    return assets;
  }

  /// Normalizes a path to use forward slashes and consistent format.
  String _normalizePath(String p) {
    // Convert backslashes to forward slashes
    var normalized = p.replaceAll('\\', '/');

    // Remove leading ./
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }

    // Remove leading /
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  /// Checks if a string contains glob pattern characters.
  bool _containsGlobPattern(String s) {
    return s.contains('*') || s.contains('?') || s.contains('[');
  }

  /// Gets a list of all asset paths as simple strings.
  Future<List<String>> getAssetPaths() async {
    final assets = await discoverAssets();
    return assets.map((a) => a.normalizedPath).toList()..sort();
  }

  /// Gets the total size of all declared assets.
  Future<int> getTotalAssetSize() async {
    final assets = await discoverAssets();
    return assets.fold<int>(0, (sum, asset) => sum + (asset.fileSize ?? 0));
  }
}

/// Exception thrown when asset discovery fails.
class AssetDiscoveryException implements Exception {
  final String message;

  AssetDiscoveryException(this.message);

  @override
  String toString() => 'AssetDiscoveryException: $message';
}
