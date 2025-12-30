import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Result of visiting a Dart AST for asset references.
class AssetVisitorResult {
  /// Direct string literal asset references found.
  final Set<String> staticAssets;

  /// Dynamic asset patterns detected (interpolation, concatenation).
  final Set<DynamicAssetReference> dynamicReferences;

  /// Assets referenced via @KeepAsset annotations.
  final Set<String> annotatedAssets;

  /// Source locations of all references for reporting.
  final List<AssetReference> allReferences;

  AssetVisitorResult({
    required this.staticAssets,
    required this.dynamicReferences,
    required this.annotatedAssets,
    required this.allReferences,
  });

  /// Combines two results.
  AssetVisitorResult merge(AssetVisitorResult other) {
    return AssetVisitorResult(
      staticAssets: {...staticAssets, ...other.staticAssets},
      dynamicReferences: {...dynamicReferences, ...other.dynamicReferences},
      annotatedAssets: {...annotatedAssets, ...other.annotatedAssets},
      allReferences: [...allReferences, ...other.allReferences],
    );
  }
}

/// Represents a reference to an asset in source code.
class AssetReference {
  /// The asset path or pattern.
  final String assetPath;

  /// Source file where the reference was found.
  final String sourceFile;

  /// Line number of the reference.
  final int line;

  /// Column number of the reference.
  final int column;

  /// Type of reference (static, dynamic, annotated).
  final AssetReferenceType type;

  /// The full expression containing the reference.
  final String? expression;

  const AssetReference({
    required this.assetPath,
    required this.sourceFile,
    required this.line,
    required this.column,
    required this.type,
    this.expression,
  });

  @override
  String toString() =>
      'AssetReference($assetPath at $sourceFile:$line:$column)';
}

/// Type of asset reference.
enum AssetReferenceType {
  /// Direct string literal: 'assets/image.png'
  static,

  /// String interpolation: 'assets/$name.png'
  interpolation,

  /// String concatenation: 'assets/' + name + '.png'
  concatenation,

  /// Adjacent strings: 'assets/' 'image.png'
  adjacentStrings,

  /// Annotation: @KeepAsset('assets/image.png')
  annotation,
}

/// Represents a dynamic asset reference that cannot be statically resolved.
class DynamicAssetReference {
  /// The static prefix that was extracted.
  final String staticPrefix;

  /// The static suffix (if any).
  final String? staticSuffix;

  /// A glob-like pattern for matching.
  final String inferredPattern;

  /// Source location information.
  final String sourceFile;
  final int line;
  final int column;

  /// The original expression.
  final String originalExpression;

  const DynamicAssetReference({
    required this.staticPrefix,
    this.staticSuffix,
    required this.inferredPattern,
    required this.sourceFile,
    required this.line,
    required this.column,
    required this.originalExpression,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicAssetReference &&
        other.inferredPattern == inferredPattern;
  }

  @override
  int get hashCode => inferredPattern.hashCode;

  @override
  String toString() =>
      'DynamicAssetReference($inferredPattern at $sourceFile:$line)';
}

/// AST visitor that finds asset references in Dart code.
class AssetReferenceVisitor extends RecursiveAstVisitor<void> {
  /// Asset path prefixes to look for.
  final List<String> assetPrefixes;

  /// Annotation names that mark assets as required.
  final List<String> keepAnnotations;

  /// Source file being analyzed.
  final String sourceFile;

  /// Found static asset paths.
  final Set<String> _staticAssets = {};

  /// Found dynamic asset references.
  final Set<DynamicAssetReference> _dynamicReferences = {};

  /// Found annotated asset paths.
  final Set<String> _annotatedAssets = {};

  /// All references with location info.
  final List<AssetReference> _allReferences = [];

  AssetReferenceVisitor({
    required this.sourceFile,
    this.assetPrefixes = const ['assets/', 'packages/'],
    this.keepAnnotations = const ['KeepAsset', 'KeepAssets', 'PreserveAsset'],
  });

  /// Gets the result of the visit.
  AssetVisitorResult get result => AssetVisitorResult(
        staticAssets: _staticAssets,
        dynamicReferences: _dynamicReferences,
        annotatedAssets: _annotatedAssets,
        allReferences: _allReferences,
      );

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final value = node.value;
    if (_looksLikeAssetPath(value)) {
      _staticAssets.add(_normalizePath(value));
      _addReference(
        value,
        node,
        AssetReferenceType.static,
      );
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    // Try to extract static prefix and suffix
    final parts = _analyzeInterpolation(node);

    if (parts != null && _looksLikeAssetPath(parts.prefix)) {
      final pattern = _buildPattern(parts.prefix, parts.suffix);
      final reference = DynamicAssetReference(
        staticPrefix: parts.prefix,
        staticSuffix: parts.suffix,
        inferredPattern: pattern,
        sourceFile: sourceFile,
        line: _getLine(node),
        column: _getColumn(node),
        originalExpression: node.toSource(),
      );
      _dynamicReferences.add(reference);
      _addReference(
        pattern,
        node,
        AssetReferenceType.interpolation,
        expression: node.toSource(),
      );
    }

    super.visitStringInterpolation(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    // Handle string concatenation: 'assets/' + name + '.png'
    if (node.operator.lexeme == '+') {
      final parts = _analyzeConcatenation(node);
      if (parts != null && _looksLikeAssetPath(parts.prefix)) {
        final pattern = _buildPattern(parts.prefix, parts.suffix);
        final reference = DynamicAssetReference(
          staticPrefix: parts.prefix,
          staticSuffix: parts.suffix,
          inferredPattern: pattern,
          sourceFile: sourceFile,
          line: _getLine(node),
          column: _getColumn(node),
          originalExpression: node.toSource(),
        );
        _dynamicReferences.add(reference);
        _addReference(
          pattern,
          node,
          AssetReferenceType.concatenation,
          expression: node.toSource(),
        );
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    // Handle adjacent strings: 'assets/' 'image.png'
    final buffer = StringBuffer();
    var hasNonLiteral = false;

    for (final string in node.strings) {
      if (string is SimpleStringLiteral) {
        buffer.write(string.value);
      } else {
        hasNonLiteral = true;
        break;
      }
    }

    if (!hasNonLiteral) {
      final value = buffer.toString();
      if (_looksLikeAssetPath(value)) {
        _staticAssets.add(_normalizePath(value));
        _addReference(
          value,
          node,
          AssetReferenceType.adjacentStrings,
        );
      }
    }

    super.visitAdjacentStrings(node);
  }

  @override
  void visitAnnotation(Annotation node) {
    final name = node.name.name;

    if (keepAnnotations.contains(name)) {
      // Extract asset paths from annotation arguments
      final arguments = node.arguments;
      if (arguments != null) {
        for (final arg in arguments.arguments) {
          _extractAnnotationAssets(arg);
        }
      }
    }

    super.visitAnnotation(node);
  }

  /// Extracts asset paths from annotation arguments.
  void _extractAnnotationAssets(Expression arg) {
    if (arg is SimpleStringLiteral) {
      final value = arg.value;
      _annotatedAssets.add(_normalizePath(value));
      _addReference(
        value,
        arg,
        AssetReferenceType.annotation,
      );
    } else if (arg is ListLiteral) {
      for (final element in arg.elements) {
        if (element is SimpleStringLiteral) {
          _annotatedAssets.add(_normalizePath(element.value));
          _addReference(
            element.value,
            element,
            AssetReferenceType.annotation,
          );
        }
      }
    }
  }

  /// Checks if a string looks like an asset path.
  bool _looksLikeAssetPath(String value) {
    final normalized = _normalizePath(value);
    return assetPrefixes.any((prefix) => normalized.startsWith(prefix));
  }

  /// Normalizes a path string.
  String _normalizePath(String p) {
    var normalized = p.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  /// Analyzes a string interpolation to extract static parts.
  _InterpolationParts? _analyzeInterpolation(StringInterpolation node) {
    String? prefix;
    String? suffix;

    final elements = node.elements;
    if (elements.isEmpty) return null;

    // Get prefix from first element if it's a string
    final first = elements.first;
    if (first is InterpolationString) {
      prefix = first.value;
    }

    // Get suffix from last element if it's a string
    if (elements.length > 1) {
      final last = elements.last;
      if (last is InterpolationString) {
        suffix = last.value;
      }
    }

    if (prefix == null || prefix.isEmpty) return null;

    return _InterpolationParts(prefix: prefix, suffix: suffix);
  }

  /// Analyzes string concatenation to extract static parts.
  _InterpolationParts? _analyzeConcatenation(BinaryExpression node) {
    final parts = <String>[];
    var hasVariable = false;
    String? suffix;

    void extract(Expression expr) {
      if (expr is SimpleStringLiteral) {
        if (hasVariable) {
          suffix = expr.value;
        } else {
          parts.add(expr.value);
        }
      } else if (expr is BinaryExpression && expr.operator.lexeme == '+') {
        extract(expr.leftOperand);
        extract(expr.rightOperand);
      } else {
        hasVariable = true;
      }
    }

    extract(node);

    if (parts.isEmpty) return null;

    return _InterpolationParts(prefix: parts.join(), suffix: suffix);
  }

  /// Builds a glob-like pattern from prefix and suffix.
  String _buildPattern(String prefix, String? suffix) {
    if (suffix != null && suffix.isNotEmpty) {
      return '$prefix*$suffix';
    }
    return '$prefix*';
  }

  /// Gets line number for a node.
  int _getLine(AstNode node) {
    // This requires the compilation unit to be available
    // For now, return offset-based approximate line
    return node.offset;
  }

  /// Gets column number for a node.
  int _getColumn(AstNode node) {
    return 0;
  }

  /// Adds a reference to the list.
  void _addReference(
    String assetPath,
    AstNode node,
    AssetReferenceType type, {
    String? expression,
  }) {
    _allReferences.add(AssetReference(
      assetPath: _normalizePath(assetPath),
      sourceFile: sourceFile,
      line: _getLine(node),
      column: _getColumn(node),
      type: type,
      expression: expression,
    ));
  }
}

/// Helper class for interpolation analysis.
class _InterpolationParts {
  final String prefix;
  final String? suffix;

  _InterpolationParts({required this.prefix, this.suffix});
}
