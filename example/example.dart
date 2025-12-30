// ignore_for_file: avoid_print
/// Example demonstrating how to use asset_tree_shaker programmatically.
///
/// This example shows how to:
/// 1. Load configuration
/// 2. Discover declared assets
/// 3. Scan for asset usages
/// 4. Analyze and report unused assets
library;

import 'dart:io';

import 'package:asset_tree_shaker/asset_tree_shaker.dart';

Future<void> main() async {
  // Get the project root (current directory in this example)
  final projectRoot = Directory.current.path;

  print('🔍 Asset Tree Shaker Example');
  print('Project: $projectRoot\n');

  // Step 1: Load configuration
  print('Loading configuration...');
  final configLoader = ConfigLoader(projectRoot: projectRoot);
  final config = await configLoader.load();
  print('  Scan paths: ${config.scanPaths}');
  print('  Strict mode: ${config.strictMode}\n');

  // Step 2: Discover declared assets from pubspec.yaml
  print('Discovering declared assets...');
  final discovery = AssetDiscovery(projectRoot: projectRoot);

  try {
    final declaredAssets = await discovery.discoverAssets();
    print('  Found ${declaredAssets.length} declared assets\n');

    // Step 3: Scan Dart files for asset references
    print('Scanning Dart files for asset usages...');
    final scanner = UsageScanner(projectRoot: projectRoot, config: config);
    final scanResult = await scanner.scan();
    print('  Scanned ${scanResult.scannedFiles.length} files');
    print('  Found ${scanResult.staticAssets.length} static references');
    print(
        '  Found ${scanResult.dynamicReferences.length} dynamic references\n');

    // Step 4: Analyze asset usage
    print('Analyzing asset usage...');
    final analyzer = GraphAnalyzer(config: config);
    final result = analyzer.analyze(
      declaredAssets: declaredAssets,
      scanResult: scanResult,
      projectRoot: projectRoot,
    );

    // Step 5: Print results
    print('\n📊 Analysis Results:');
    print('  Total assets: ${result.summary.totalAssets}');
    print('  Used assets: ${result.summary.usedAssets}');
    print('  Unused assets: ${result.summary.unusedAssets}');
    print('  Total size: ${result.summary.totalSizeFormatted}');
    print('  Unused size: ${result.summary.unusedSizeFormatted}');

    if (result.unusedAssets.isNotEmpty) {
      print('\n🗑️ Unused Assets:');
      for (final asset in result.unusedAssets) {
        print('  - ${asset.path}');
      }
    } else {
      print('\n✅ No unused assets found!');
    }

    // Step 6: Generate a report (optional)
    if (config.generateReport) {
      print('\n📝 Generating report...');
      final reporter = ReportGenerator(result: result);
      final report = reporter.generate(config.reportFormat);

      final reportFile = File('$projectRoot/asset_report.md');
      await reportFile.writeAsString(report);
      print('  Report saved to: ${reportFile.path}');
    }
  } on AssetDiscoveryException catch (e) {
    print('❌ Error: $e');
    print('   Make sure you have a valid pubspec.yaml with assets declared.');
  }
}
