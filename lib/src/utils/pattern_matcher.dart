import 'package:glob/glob.dart';

/// Utility class for matching asset paths against glob patterns.
class PatternMatcher {
  final List<String> excludePatterns;
  final List<String> dynamicPatterns;

  final List<Glob> _excludeGlobs;
  final List<Glob> _dynamicGlobs;

  PatternMatcher({
    required this.excludePatterns,
    required this.dynamicPatterns,
  })  : _excludeGlobs = excludePatterns.map((p) => Glob(p)).toList(),
        _dynamicGlobs = dynamicPatterns.map((p) => Glob(p)).toList();

  /// Checks if a path matches any exclude pattern.
  bool matchesExcludePattern(String path) {
    return _matchesAnyGlob(path, _excludeGlobs);
  }

  /// Checks if a path matches any dynamic pattern.
  bool matchesDynamicPattern(String path) {
    return _matchesAnyGlob(path, _dynamicGlobs);
  }

  /// Gets the first matching exclude pattern for a path.
  String? getMatchingExcludePattern(String path) {
    for (var i = 0; i < _excludeGlobs.length; i++) {
      if (_excludeGlobs[i].matches(path)) {
        return excludePatterns[i];
      }
    }
    return null;
  }

  /// Gets the first matching dynamic pattern for a path.
  String? getMatchingDynamicPattern(String path) {
    for (var i = 0; i < _dynamicGlobs.length; i++) {
      if (_dynamicGlobs[i].matches(path)) {
        return dynamicPatterns[i];
      }
    }
    return null;
  }

  /// Checks if a path matches any of the given globs.
  bool _matchesAnyGlob(String path, List<Glob> globs) {
    for (final glob in globs) {
      if (glob.matches(path)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if an asset path matches a simple pattern with wildcards.
  ///
  /// Supports:
  /// - `*` matches any sequence of characters except `/`
  /// - `**` matches any sequence of characters including `/`
  /// - `?` matches any single character
  static bool matchesSimplePattern(String path, String pattern) {
    // Convert simple pattern to regex
    final regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('**', '{{DOUBLESTAR}}')
        .replaceAll('*', r'[^/]*')
        .replaceAll('{{DOUBLESTAR}}', '.*')
        .replaceAll('?', '.');

    final regex = RegExp('^$regexPattern\$');
    return regex.hasMatch(path);
  }

  /// Extracts the static prefix from a pattern (before first wildcard).
  static String extractStaticPrefix(String pattern) {
    final wildcardIndex = pattern.indexOf(RegExp(r'[\*\?\[]'));
    if (wildcardIndex == -1) {
      return pattern;
    }
    return pattern.substring(0, wildcardIndex);
  }

  /// Extracts the static suffix from a pattern (after last wildcard).
  static String? extractStaticSuffix(String pattern) {
    // Find the last wildcard
    final lastStar = pattern.lastIndexOf('*');
    final lastQuestion = pattern.lastIndexOf('?');
    final lastBracket = pattern.lastIndexOf(']');

    final lastWildcard = [lastStar, lastQuestion, lastBracket]
        .where((i) => i != -1)
        .fold<int>(-1, (a, b) => a > b ? a : b);

    if (lastWildcard == -1 || lastWildcard >= pattern.length - 1) {
      return null;
    }

    return pattern.substring(lastWildcard + 1);
  }

  /// Finds all patterns that match a given path.
  List<String> findMatchingPatterns(String path, List<String> patterns) {
    return patterns.where((p) => matchesSimplePattern(path, p)).toList();
  }

  /// Groups paths by their directory.
  static Map<String, List<String>> groupByDirectory(List<String> paths) {
    final groups = <String, List<String>>{};

    for (final path in paths) {
      final lastSlash = path.lastIndexOf('/');
      final dir = lastSlash != -1 ? path.substring(0, lastSlash) : '';
      groups.putIfAbsent(dir, () => []).add(path);
    }

    return groups;
  }

  /// Infers a pattern from a set of similar paths.
  ///
  /// For example, given:
  /// - assets/images/avatar_1.png
  /// - assets/images/avatar_2.png
  /// - assets/images/avatar_3.png
  ///
  /// Returns: assets/images/avatar_*.png
  static String? inferPattern(List<String> paths) {
    if (paths.isEmpty) return null;
    if (paths.length == 1) return paths.first;

    // Find common prefix
    final prefix = _longestCommonPrefix(paths);
    if (prefix.isEmpty) return null;

    // Find common suffix
    final suffix = _longestCommonSuffix(paths);

    if (prefix == suffix) {
      // All paths are identical
      return paths.first;
    }

    // Check if the varying part is just numbers or short identifiers
    final varying = paths.map((p) {
      final start = prefix.length;
      final end = p.length - suffix.length;
      return p.substring(start, end);
    }).toList();

    // If all varying parts are numbers, it's a good pattern
    final allNumbers = varying.every((v) => RegExp(r'^\d+$').hasMatch(v));
    if (allNumbers) {
      return '$prefix*$suffix';
    }

    // If all varying parts are short (< 20 chars), suggest pattern
    final allShort = varying.every((v) => v.length < 20);
    if (allShort) {
      return '$prefix*$suffix';
    }

    return null;
  }

  static String _longestCommonPrefix(List<String> strings) {
    if (strings.isEmpty) return '';
    if (strings.length == 1) return strings.first;

    var prefix = strings.first;
    for (var i = 1; i < strings.length; i++) {
      while (!strings[i].startsWith(prefix)) {
        prefix = prefix.substring(0, prefix.length - 1);
        if (prefix.isEmpty) return '';
      }
    }
    return prefix;
  }

  static String _longestCommonSuffix(List<String> strings) {
    if (strings.isEmpty) return '';
    if (strings.length == 1) return strings.first;

    final reversed = strings.map((s) => s.split('').reversed.join()).toList();
    final commonReversed = _longestCommonPrefix(reversed);
    return commonReversed.split('').reversed.join();
  }
}
