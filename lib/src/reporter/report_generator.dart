import 'dart:convert';

import '../analyzer/analysis_result.dart';
import '../config/config.dart';

/// Generates reports from analysis results.
class ReportGenerator {
  final AnalysisResult result;

  ReportGenerator({required this.result});

  /// Generates a report in the specified format.
  String generate(ReportFormat format) {
    switch (format) {
      case ReportFormat.markdown:
        return generateMarkdown();
      case ReportFormat.json:
        return generateJson();
      case ReportFormat.html:
        return generateHtml();
    }
  }

  /// Generates a Markdown report.
  String generateMarkdown() {
    final buffer = StringBuffer();
    final summary = result.summary;

    buffer.writeln('# Asset Tree Shaker Report');
    buffer.writeln();
    buffer.writeln('Generated: ${result.timestamp.toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Project: `${result.projectRoot}`');
    buffer.writeln();

    // Summary section
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('| Metric | Count |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Total Assets | ${summary.totalAssets} |');
    buffer.writeln('| Used Assets | ${summary.usedAssets} |');
    buffer.writeln('| **Unused Assets** | **${summary.unusedAssets}** |');
    buffer.writeln('| Whitelisted | ${summary.whitelistedAssets} |');
    buffer.writeln('| Dynamic Match | ${summary.dynamicMatchAssets} |');
    buffer.writeln('| Annotated | ${summary.annotatedAssets} |');
    buffer.writeln('| Missing Files | ${summary.missingAssets} |');
    buffer.writeln('| Files Scanned | ${result.filesScanned} |');
    buffer.writeln();
    buffer.writeln('### Size Analysis');
    buffer.writeln();
    buffer.writeln('- Total asset size: **${summary.totalSizeFormatted}**');
    buffer.writeln('- Unused asset size: **${summary.unusedSizeFormatted}** '
        '(${summary.unusedSizePercentage.toStringAsFixed(1)}%)');
    buffer.writeln();

    // Unused assets section
    if (result.unusedAssets.isNotEmpty) {
      buffer.writeln('## 🗑️ Unused Assets');
      buffer.writeln();
      buffer.writeln(
          'The following assets appear to have no references in your code:');
      buffer.writeln();
      buffer.writeln('| Asset Path | Size |');
      buffer.writeln('|------------|------|');
      for (final asset in result.unusedAssets) {
        final size = _formatBytes(asset.fileSize ?? 0);
        buffer.writeln('| `${asset.path}` | $size |');
      }
      buffer.writeln();
    }

    // Dynamic warnings
    if (result.warnings.isNotEmpty) {
      buffer.writeln('## ⚠️ Dynamic Usage Warnings');
      buffer.writeln();
      buffer.writeln('The following dynamic asset references were detected. '
          'Consider adding them to `dynamic_patterns` in your config:');
      buffer.writeln();
      for (final warning in result.warnings) {
        buffer.writeln('### Pattern: `${warning.reference.inferredPattern}`');
        buffer.writeln();
        buffer.writeln(
            '- Location: `${warning.reference.sourceFile}:${warning.reference.line}`');
        buffer
            .writeln('- Expression: `${warning.reference.originalExpression}`');
        buffer.writeln(
            '- Potentially affected assets: ${warning.potentiallyAffectedAssets.length}');
        buffer.writeln();
        buffer.writeln('Suggested config:');
        buffer.writeln('```yaml');
        buffer.writeln(warning.suggestedConfig);
        buffer.writeln('```');
        buffer.writeln();
      }
    }

    // Whitelisted assets
    if (result.whitelistedAssets.isNotEmpty) {
      buffer.writeln('## ✅ Whitelisted Assets');
      buffer.writeln();
      buffer.writeln(
          'These assets are excluded from analysis via configuration:');
      buffer.writeln();
      for (final asset in result.whitelistedAssets) {
        buffer
            .writeln('- `${asset.path}` (matched: `${asset.matchedPattern}`)');
      }
      buffer.writeln();
    }

    // Dynamic match assets
    if (result.dynamicMatchAssets.isNotEmpty) {
      buffer.writeln('## 🔄 Dynamic Match Assets');
      buffer.writeln();
      buffer.writeln('These assets match dynamic patterns and are preserved:');
      buffer.writeln();
      for (final asset in result.dynamicMatchAssets) {
        buffer
            .writeln('- `${asset.path}` (matched: `${asset.matchedPattern}`)');
      }
      buffer.writeln();
    }

    // Missing assets
    if (result.missingAssets.isNotEmpty) {
      buffer.writeln('## ❓ Missing Assets');
      buffer.writeln();
      buffer.writeln(
          'These assets are declared in pubspec.yaml but the files are missing:');
      buffer.writeln();
      for (final asset in result.missingAssets) {
        buffer.writeln('- `${asset.path}`');
      }
      buffer.writeln();
    }

    // Errors
    if (result.errors.isNotEmpty) {
      buffer.writeln('## ❌ Errors');
      buffer.writeln();
      for (final error in result.errors) {
        buffer.writeln('- $error');
      }
      buffer.writeln();
    }

    // Recommendations
    buffer.writeln('## Recommendations');
    buffer.writeln();
    if (result.unusedAssets.isEmpty) {
      buffer.writeln('🎉 **Great job!** No unused assets detected.');
    } else {
      buffer.writeln('1. Review the unused assets list above');
      buffer.writeln(
          '2. Verify they are truly unused (check for dynamic references)');
      buffer
          .writeln('3. Run `dart run asset_tree_shaker clean` to remove them');
      buffer.writeln(
          '4. Add false positives to `exclude_patterns` in your config');
    }

    return buffer.toString();
  }

  /// Generates a JSON report.
  String generateJson() {
    final summary = result.summary;

    final data = {
      'timestamp': result.timestamp.toIso8601String(),
      'projectRoot': result.projectRoot,
      'filesScanned': result.filesScanned,
      'summary': {
        'totalAssets': summary.totalAssets,
        'usedAssets': summary.usedAssets,
        'unusedAssets': summary.unusedAssets,
        'whitelistedAssets': summary.whitelistedAssets,
        'dynamicMatchAssets': summary.dynamicMatchAssets,
        'annotatedAssets': summary.annotatedAssets,
        'missingAssets': summary.missingAssets,
        'totalSizeBytes': summary.totalSizeBytes,
        'unusedSizeBytes': summary.unusedSizeBytes,
        'unusedPercentage': summary.unusedPercentage,
      },
      'unusedAssets': result.unusedAssets
          .map((a) => {
                'path': a.path,
                'sizeBytes': a.fileSize,
                'originalDeclaration': a.originalDeclaration,
              })
          .toList(),
      'usedAssets': result.usedAssets
          .map((a) => {
                'path': a.path,
                'sizeBytes': a.fileSize,
                'references': a.references
                    .map((r) => {
                          'file': r.sourceFile,
                          'line': r.line,
                          'type': r.type.name,
                        })
                    .toList(),
              })
          .toList(),
      'warnings': result.warnings
          .map((w) => {
                'pattern': w.reference.inferredPattern,
                'sourceFile': w.reference.sourceFile,
                'line': w.reference.line,
                'expression': w.reference.originalExpression,
                'affectedAssets': w.potentiallyAffectedAssets,
                'suggestedConfig': w.suggestedConfig,
              })
          .toList(),
      'whitelistedAssets': result.whitelistedAssets
          .map((a) => {
                'path': a.path,
                'matchedPattern': a.matchedPattern,
              })
          .toList(),
      'dynamicMatchAssets': result.dynamicMatchAssets
          .map((a) => {
                'path': a.path,
                'matchedPattern': a.matchedPattern,
              })
          .toList(),
      'missingAssets': result.missingAssets.map((a) => a.path).toList(),
      'errors': result.errors,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Generates an HTML report.
  String generateHtml() {
    final summary = result.summary;
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln(
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>Asset Tree Shaker Report</title>');
    buffer.writeln('  <style>');
    buffer.writeln(_htmlStyles);
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Header
    buffer.writeln('<div class="container">');
    buffer.writeln('  <h1>🌳 Asset Tree Shaker Report</h1>');
    buffer.writeln(
        '  <p class="meta">Generated: ${result.timestamp.toIso8601String()}</p>');
    buffer.writeln(
        '  <p class="meta">Project: <code>${result.projectRoot}</code></p>');

    // Summary cards
    buffer.writeln('  <div class="summary-cards">');
    buffer.writeln('    <div class="card">');
    buffer
        .writeln('      <div class="card-value">${summary.totalAssets}</div>');
    buffer.writeln('      <div class="card-label">Total Assets</div>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="card used">');
    buffer.writeln('      <div class="card-value">${summary.usedAssets}</div>');
    buffer.writeln('      <div class="card-label">Used</div>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="card unused">');
    buffer
        .writeln('      <div class="card-value">${summary.unusedAssets}</div>');
    buffer.writeln('      <div class="card-label">Unused</div>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="card">');
    buffer.writeln(
        '      <div class="card-value">${summary.unusedSizeFormatted}</div>');
    buffer.writeln('      <div class="card-label">Potential Savings</div>');
    buffer.writeln('    </div>');
    buffer.writeln('  </div>');

    // Unused assets table
    if (result.unusedAssets.isNotEmpty) {
      buffer.writeln('  <h2>🗑️ Unused Assets</h2>');
      buffer.writeln('  <table>');
      buffer.writeln(
          '    <thead><tr><th>Asset Path</th><th>Size</th></tr></thead>');
      buffer.writeln('    <tbody>');
      for (final asset in result.unusedAssets) {
        final size = _formatBytes(asset.fileSize ?? 0);
        buffer.writeln(
            '      <tr><td><code>${asset.path}</code></td><td>$size</td></tr>');
      }
      buffer.writeln('    </tbody>');
      buffer.writeln('  </table>');
    }

    // Warnings
    if (result.warnings.isNotEmpty) {
      buffer.writeln('  <h2>⚠️ Dynamic Usage Warnings</h2>');
      buffer.writeln('  <div class="warnings">');
      for (final warning in result.warnings) {
        buffer.writeln('    <div class="warning">');
        buffer.writeln(
            '      <strong>Pattern:</strong> <code>${warning.reference.inferredPattern}</code><br>');
        buffer.writeln(
            '      <strong>Location:</strong> ${warning.reference.sourceFile}:${warning.reference.line}<br>');
        buffer.writeln(
            '      <strong>Affected:</strong> ${warning.potentiallyAffectedAssets.length} assets');
        buffer.writeln('    </div>');
      }
      buffer.writeln('  </div>');
    }

    buffer.writeln('</div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static const _htmlStyles = '''
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; background: #f5f5f5; color: #333; }
    .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
    h1 { margin-bottom: 0.5rem; }
    h2 { margin: 2rem 0 1rem; padding-bottom: 0.5rem; border-bottom: 2px solid #eee; }
    .meta { color: #666; font-size: 0.9rem; }
    code { background: #e8e8e8; padding: 0.2rem 0.4rem; border-radius: 3px; font-size: 0.9em; }
    .summary-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1rem; margin: 2rem 0; }
    .card { background: white; padding: 1.5rem; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .card.used { border-left: 4px solid #4caf50; }
    .card.unused { border-left: 4px solid #f44336; }
    .card-value { font-size: 2rem; font-weight: bold; }
    .card-label { color: #666; font-size: 0.9rem; }
    table { width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    th, td { padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid #eee; }
    th { background: #f8f8f8; font-weight: 600; }
    tr:last-child td { border-bottom: none; }
    .warnings { display: flex; flex-direction: column; gap: 1rem; }
    .warning { background: #fff3cd; border: 1px solid #ffc107; padding: 1rem; border-radius: 8px; }
  ''';
}
