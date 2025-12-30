import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import 'package:asset_tree_shaker/asset_tree_shaker.dart';

/// CLI entry point for asset_tree_shaker.
Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'asset_tree_shaker',
    'Detect and remove unused assets from Flutter projects.',
  )
    ..addCommand(CheckCommand())
    ..addCommand(AnalyzeCommand())
    ..addCommand(CleanCommand())
    ..addCommand(ReportCommand())
    ..addCommand(InitCommand())
    ..addCommand(RestoreCommand());

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    print(e);
    exit(64); // EX_USAGE
  } catch (e, stackTrace) {
    print('Error: $e');
    if (Platform.environment['DEBUG'] == 'true') {
      print(stackTrace);
    }
    exit(1);
  }
}

/// Base command with common options.
abstract class BaseCommand extends Command<int> {
  BaseCommand() {
    argParser.addOption(
      'project',
      abbr: 'p',
      help: 'Path to the Flutter project root.',
      defaultsTo: '.',
    );
    argParser.addOption(
      'config',
      abbr: 'c',
      help: 'Path to configuration file.',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose output.',
      negatable: false,
    );
  }

  String get projectRoot {
    final project = argResults!['project'] as String;
    return path.absolute(project);
  }

  bool get verbose => argResults!['verbose'] as bool;

  Future<AssetTreeShakerConfig> loadConfig() async {
    final configPath = argResults!['config'] as String?;
    final loader = ConfigLoader(projectRoot: projectRoot);

    if (configPath != null) {
      // Load from specific path
      final file = File(configPath);
      if (!await file.exists()) {
        throw UsageException('Config file not found: $configPath', usage);
      }
    }

    return loader.load();
  }

  void printVerbose(String message) {
    if (verbose) {
      print(message);
    }
  }

  void printSuccess(String message) {
    print('\x1B[32m✓\x1B[0m $message');
  }

  void printWarning(String message) {
    print('\x1B[33m⚠\x1B[0m $message');
  }

  void printError(String message) {
    print('\x1B[31m✗\x1B[0m $message');
  }

  void printInfo(String message) {
    print('\x1B[34mℹ\x1B[0m $message');
  }
}

/// Command to check assets, show status, generate report, and optionally clean - all in one.
class CheckCommand extends BaseCommand {
  @override
  final name = 'check';

  @override
  final description =
      'Analyze assets, show used/unused status, generate report, and optionally clean.';

  CheckCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output path for the report file.',
      defaultsTo: 'asset_report.md',
    );
    argParser.addFlag(
      'no-report',
      help: 'Skip generating report file.',
      negatable: false,
    );
    argParser.addFlag(
      'clean',
      help: 'Prompt to clean unused assets after analysis.',
      negatable: false,
      defaultsTo: true,
    );
  }

  @override
  Future<int> run() async {
    final config = await loadConfig();
    final outputPath = argResults!['output'] as String;
    final noReport = argResults!['no-report'] as bool;

    print('');
    print('┌─────────────────────────────────────────────────────────────┐');
    print('│                 🌳 Asset Tree Shaker                        │');
    print('└─────────────────────────────────────────────────────────────┘');
    print('');
    print('📂 Project: $projectRoot');
    print('');

    // Discover assets
    print('🔍 Scanning...');
    final discovery = AssetDiscovery(projectRoot: projectRoot);
    final declaredAssets = await discovery.discoverAssets();

    // Scan for usages
    final scanner = UsageScanner(projectRoot: projectRoot, config: config);
    final scanResult = await scanner.scan();

    // Analyze
    final analyzer = GraphAnalyzer(config: config);
    final result = analyzer.analyze(
      declaredAssets: declaredAssets,
      scanResult: scanResult,
      projectRoot: projectRoot,
    );

    // Print asset list with status
    print('');
    print('┌─────────────────────────────────────────────────────────────┐');
    print('│                     Asset Status                            │');
    print('├─────────────────────────────────────────────────────────────┤');

    // Sort assets: unused first, then used
    final allAssets = [...result.assets];
    allAssets.sort((a, b) {
      if (a.status == AssetStatus.unused && b.status != AssetStatus.unused) {
        return -1;
      }
      if (a.status != AssetStatus.unused && b.status == AssetStatus.unused) {
        return 1;
      }
      return a.path.compareTo(b.path);
    });

    for (final asset in allAssets) {
      final status = _getStatusLabel(asset.status);
      final size = _formatBytes(asset.fileSize ?? 0);
      final fileName = asset.path.length > 45
          ? '...${asset.path.substring(asset.path.length - 42)}'
          : asset.path;
      print('│ $status ${fileName.padRight(45)} $size');
    }

    print('└─────────────────────────────────────────────────────────────┘');
    print('');

    // Summary
    final summary = result.summary;
    print('📊 Summary:');
    print('   ✅ Used:     ${summary.usedAssets}');
    print('   ❌ Unused:   ${summary.unusedAssets}');
    print(
        '   ⏭️  Skipped:  ${summary.whitelistedAssets + summary.dynamicMatchAssets + summary.annotatedAssets}');
    print('');
    print('   💾 Total size:   ${summary.totalSizeFormatted}');
    print(
        '   🗑️  Unused size:  ${summary.unusedSizeFormatted} (${summary.unusedSizePercentage.toStringAsFixed(1)}% savings)');
    print('');

    // Generate report
    if (!noReport) {
      final generator = ReportGenerator(result: result);
      final report = generator.generate(ReportFormat.markdown);
      final reportFile = File(path.join(projectRoot, outputPath));
      await reportFile.writeAsString(report);
      printSuccess('Report saved: $outputPath');
      print('');
    }

    // Ask to clean if there are unused assets
    if (result.unusedAssets.isNotEmpty) {
      print('─────────────────────────────────────────────────────────────');
      print('');
      print(
          '⚠️  Found ${result.unusedAssets.length} unused assets (${_formatBytes(result.unusedAssetsSize)})');
      print('');
      stdout.write('🧹 Do you want to delete these unused assets? [y/N]: ');
      final response = stdin.readLineSync()?.toLowerCase().trim();

      if (response == 'y' || response == 'yes') {
        print('');
        print('Creating backup...');
        final cleaner = AssetCleaner(projectRoot: projectRoot);
        final cleanResult = await cleaner.clean(
          analysisResult: result,
          dryRun: false,
          createBackup: true,
          removeFromPubspec: false,
        );

        print('');
        if (cleanResult.backupFile != null) {
          printInfo('Backup: ${path.basename(cleanResult.backupFile!)}');
        }
        printSuccess(
            'Deleted ${cleanResult.deletedAssets.length} unused assets!');
        print('   Freed: ${_formatBytes(cleanResult.totalDeletedSize)}');

        if (cleanResult.hasFailures) {
          print('');
          printWarning(
              '${cleanResult.failedDeletions.length} files could not be deleted.');
        }
      } else {
        print('');
        printInfo('No assets were deleted.');
      }
    } else {
      printSuccess('All assets are in use! 🎉');
    }

    print('');
    return 0;
  }

  String _getStatusLabel(AssetStatus status) {
    switch (status) {
      case AssetStatus.used:
        return '\x1B[32m✓ USED    \x1B[0m';
      case AssetStatus.unused:
        return '\x1B[31m✗ UNUSED  \x1B[0m';
      case AssetStatus.whitelisted:
        return '\x1B[33m⏭ SKIPPED \x1B[0m';
      case AssetStatus.dynamicMatch:
        return '\x1B[33m⏭ DYNAMIC \x1B[0m';
      case AssetStatus.annotated:
        return '\x1B[34m📌 KEPT   \x1B[0m';
      case AssetStatus.missing:
        return '\x1B[35m? MISSING \x1B[0m';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes.toString().padLeft(6)} B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1).padLeft(6)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).padLeft(6)} MB';
  }
}

/// Command to analyze assets and report unused ones.
class AnalyzeCommand extends BaseCommand {
  @override
  final name = 'analyze';

  @override
  final description = 'Analyze assets and report unused ones.';

  AnalyzeCommand() {
    argParser.addFlag(
      'strict',
      abbr: 's',
      help: 'Fail with exit code 1 if unused assets are found.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    final config = await loadConfig();
    final strictMode = argResults!['strict'] as bool || config.strictMode;

    print('🔍 Analyzing assets in $projectRoot...');
    print('');

    // Discover assets
    printVerbose('Discovering declared assets...');
    final discovery = AssetDiscovery(projectRoot: projectRoot);
    final declaredAssets = await discovery.discoverAssets();
    printInfo('Found ${declaredAssets.length} declared assets');

    // Scan for usages
    printVerbose('Scanning Dart files for asset references...');
    final scanner = UsageScanner(projectRoot: projectRoot, config: config);
    final scanResult = await scanner.scan();
    printInfo('Scanned ${scanResult.scannedFiles.length} Dart files');
    printInfo(
        'Found ${scanResult.staticAssets.length} static asset references');

    if (scanResult.dynamicReferences.isNotEmpty) {
      printWarning(
          'Detected ${scanResult.dynamicReferences.length} dynamic asset references');
    }

    // Analyze
    printVerbose('Analyzing asset usage...');
    final analyzer = GraphAnalyzer(config: config);
    final result = analyzer.analyze(
      declaredAssets: declaredAssets,
      scanResult: scanResult,
      projectRoot: projectRoot,
    );

    // Print results
    print('');
    _printSummary(result);
    print('');

    // Print unused assets
    if (result.unusedAssets.isNotEmpty) {
      printWarning('Unused assets (${result.unusedAssets.length}):');
      for (final asset in result.unusedAssets) {
        final size = _formatBytes(asset.fileSize ?? 0);
        print('  - ${asset.path} ($size)');
      }
      print('');
    }

    // Print warnings
    if (result.warnings.isNotEmpty) {
      printWarning('Dynamic usage warnings:');
      for (final warning in result.warnings) {
        print('  Pattern: ${warning.reference.inferredPattern}');
        print(
            '    Location: ${warning.reference.sourceFile}:${warning.reference.line}');
        print(
            '    Affected: ${warning.potentiallyAffectedAssets.length} assets');
        print('');
      }
    }

    // Generate report if configured
    if (config.generateReport) {
      final reportPath = config.reportOutputPath ??
          'asset_report${config.reportFormat.extension}';
      final generator = ReportGenerator(result: result);
      final report = generator.generate(config.reportFormat);
      await File(path.join(projectRoot, reportPath)).writeAsString(report);
      printSuccess('Report generated: $reportPath');
    }

    // Return exit code
    if (result.hasUnusedAssets && strictMode) {
      printError(
          'Found ${result.unusedAssets.length} unused assets (strict mode enabled)');
      return 1;
    }

    if (result.unusedAssets.isEmpty) {
      printSuccess('No unused assets found!');
    }

    return 0;
  }

  void _printSummary(AnalysisResult result) {
    final summary = result.summary;
    print('📊 Summary:');
    print('   Total assets:    ${summary.totalAssets}');
    print('   Used:            ${summary.usedAssets}');
    print('   Unused:          ${summary.unusedAssets}');
    print('   Whitelisted:     ${summary.whitelistedAssets}');
    print('   Dynamic match:   ${summary.dynamicMatchAssets}');
    print('   Annotated:       ${summary.annotatedAssets}');
    print('   Missing files:   ${summary.missingAssets}');
    print('');
    print('   Total size:      ${summary.totalSizeFormatted}');
    print(
        '   Unused size:     ${summary.unusedSizeFormatted} (${summary.unusedSizePercentage.toStringAsFixed(1)}%)');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Command to clean (delete) unused assets.
class CleanCommand extends BaseCommand {
  @override
  final name = 'clean';

  @override
  final description = 'Remove unused assets from the project.';

  CleanCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip confirmation prompt.',
      negatable: false,
    );
    argParser.addFlag(
      'dry-run',
      abbr: 'd',
      help: 'Show what would be deleted without actually deleting.',
      negatable: false,
    );
    argParser.addFlag(
      'no-backup',
      help: 'Skip creating a backup file.',
      negatable: false,
    );
    argParser.addFlag(
      'update-pubspec',
      help: 'Remove deleted assets from pubspec.yaml.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    final config = await loadConfig();
    final force = argResults!['force'] as bool;
    final dryRun = argResults!['dry-run'] as bool;
    final noBackup = argResults!['no-backup'] as bool;
    final updatePubspec = argResults!['update-pubspec'] as bool;

    print('🔍 Analyzing assets...');

    // Run analysis first
    final discovery = AssetDiscovery(projectRoot: projectRoot);
    final declaredAssets = await discovery.discoverAssets();

    final scanner = UsageScanner(projectRoot: projectRoot, config: config);
    final scanResult = await scanner.scan();

    final analyzer = GraphAnalyzer(config: config);
    final result = analyzer.analyze(
      declaredAssets: declaredAssets,
      scanResult: scanResult,
      projectRoot: projectRoot,
    );

    if (result.unusedAssets.isEmpty) {
      printSuccess('No unused assets to clean!');
      return 0;
    }

    // Show preview
    print('');
    print('Assets to be ${dryRun ? '(dry run) ' : ''}deleted:');
    for (final asset in result.unusedAssets) {
      final size = _formatBytes(asset.fileSize ?? 0);
      print('  - ${asset.path} ($size)');
    }
    print('');
    print('Total: ${result.unusedAssets.length} assets, '
        '${_formatBytes(result.unusedAssetsSize)}');
    print('');

    // Confirm once unless --force or --dry-run
    if (!force && !dryRun) {
      print(
          '⚠️  This will permanently delete ${result.unusedAssets.length} files '
          '(${_formatBytes(result.unusedAssetsSize)}).');
      stdout.write('Proceed with deletion? [y/N]: ');
      final response = stdin.readLineSync()?.toLowerCase().trim();
      if (response != 'y' && response != 'yes') {
        print('Operation cancelled.');
        return 0;
      }
      print('');
    }

    // Perform clean
    final cleaner = AssetCleaner(projectRoot: projectRoot);
    final cleanResult = await cleaner.clean(
      analysisResult: result,
      dryRun: dryRun,
      createBackup: !noBackup && !dryRun,
      removeFromPubspec: updatePubspec,
    );

    // Report results
    if (dryRun) {
      printInfo(
          'Dry run complete. ${cleanResult.deletedAssets.length} assets would be deleted.');
    } else {
      printSuccess('Deleted ${cleanResult.deletedAssets.length} assets.');

      if (cleanResult.backupFile != null) {
        printInfo('Backup created: ${cleanResult.backupFile}');
      }

      if (cleanResult.hasFailures) {
        printWarning('${cleanResult.failedDeletions.length} deletions failed:');
        for (final failure in cleanResult.failedDeletions) {
          print('  - ${failure.path}: ${failure.reason}');
        }
      }
    }

    return cleanResult.hasFailures ? 1 : 0;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Command to generate a detailed report.
class ReportCommand extends BaseCommand {
  @override
  final name = 'report';

  @override
  final description = 'Generate a detailed asset usage report.';

  ReportCommand() {
    argParser.addOption(
      'format',
      abbr: 'f',
      help: 'Report format.',
      allowed: ['markdown', 'json', 'html'],
      defaultsTo: 'markdown',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output file path.',
    );
  }

  @override
  Future<int> run() async {
    final config = await loadConfig();
    final formatStr = argResults!['format'] as String;
    final format = ReportFormatExtension.fromString(formatStr);
    final output =
        argResults!['output'] as String? ?? 'asset_report${format.extension}';

    print('🔍 Analyzing assets...');

    // Run analysis
    final discovery = AssetDiscovery(projectRoot: projectRoot);
    final declaredAssets = await discovery.discoverAssets();

    final scanner = UsageScanner(projectRoot: projectRoot, config: config);
    final scanResult = await scanner.scan();

    final analyzer = GraphAnalyzer(config: config);
    final result = analyzer.analyze(
      declaredAssets: declaredAssets,
      scanResult: scanResult,
      projectRoot: projectRoot,
    );

    // Generate report
    final generator = ReportGenerator(result: result);
    final report = generator.generate(format);

    // Write to file
    final outputPath = path.join(projectRoot, output);
    await File(outputPath).writeAsString(report);

    printSuccess('Report generated: $output');

    return 0;
  }
}

/// Command to initialize configuration file.
class InitCommand extends BaseCommand {
  @override
  final name = 'init';

  @override
  final description = 'Create a default configuration file.';

  InitCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing configuration file.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final configPath =
        path.join(projectRoot, ConfigLoader.defaultConfigFileName);

    if (!force && await File(configPath).exists()) {
      printError('Configuration file already exists: $configPath');
      print('Use --force to overwrite.');
      return 1;
    }

    final loader = ConfigLoader(projectRoot: projectRoot);
    await loader.createDefaultConfig();

    printSuccess('Created configuration file: $configPath');

    return 0;
  }
}

/// Command to restore assets from backup.
class RestoreCommand extends BaseCommand {
  @override
  final name = 'restore';

  @override
  final description = 'Restore assets from a backup file.';

  RestoreCommand() {
    argParser.addOption(
      'from',
      help: 'Path to the backup file.',
      mandatory: true,
    );
  }

  @override
  Future<int> run() async {
    final backupPath = argResults!['from'] as String;
    final absoluteBackupPath = path.isAbsolute(backupPath)
        ? backupPath
        : path.join(projectRoot, backupPath);

    print('🔄 Restoring assets from $backupPath...');

    final cleaner = AssetCleaner(projectRoot: projectRoot);

    try {
      final result = await cleaner.restore(absoluteBackupPath);

      printSuccess('Restored ${result.restoredAssets.length} assets.');

      if (result.hasFailures) {
        printWarning('${result.failedRestores.length} restores failed:');
        for (final failure in result.failedRestores) {
          print('  - ${failure.path}: ${failure.reason}');
        }
        return 1;
      }

      return 0;
    } on CleanerException catch (e) {
      printError(e.message);
      return 1;
    }
  }
}
