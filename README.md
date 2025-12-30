# Asset Tree Shaker 🌳

[![Pub Version](https://img.shields.io/pub/v/asset_tree_shaker?style=flat-square)](https://pub.dev/packages/asset_tree_shaker)
[![Dart SDK](https://img.shields.io/badge/Dart%20SDK-%3E%3D%203.0.0-blue?style=flat-square)](https://dart.dev)
[![Dart CI](https://github.com/Vanshpanchal/asset_tree_shaker/actions/workflows/ci.yml/badge.svg)](https://github.com/Vanshpanchal/asset_tree_shaker/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Pub Points](https://img.shields.io/pub/points/asset_tree_shaker?style=flat-square&logo=dart)](https://pub.dev/packages/asset_tree_shaker/score)

**v1.1.2** | [pub.dev](https://pub.dev/packages/asset_tree_shaker) | [GitHub](https://github.com/Vanshpanchal/asset_tree_shaker)

A build-time tool that **detects and removes unused assets** from Flutter projects. Uses AST (Abstract Syntax Tree) analysis to accurately identify asset references in Dart code.

## ✨ Features

- 🔍 **Smart Detection** - AST-based scanning (not just regex) for accurate results
- 📊 **Multiple Report Formats** - Generate Markdown, JSON, or HTML reports
- 🛡️ **Safe Deletion** - Automatic backup before removing assets
- ⚡ **CI/CD Ready** - Strict mode for build pipelines
- 🎯 **Dynamic Asset Support** - Handles interpolated paths with whitelist patterns
- 📝 **Annotation Support** - `@KeepAsset` to preserve specific assets
- 🧹 **One-Command Cleanup** - Analyze, report, and clean in a single command

## 📦 Installation

### As Dev Dependency

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
          asset_tree_shaker: ^1.1.2
```

Then run:

```bash
dart pub get
```

### Global Installation (CLI Only)

```bash
dart pub global activate asset_tree_shaker
```

## 🚀 Quick Start

### Recommended: One-Command Analysis & Cleanup

```bash
dart run asset_tree_shaker check
```

This single command:

- 📋 Shows all assets with ✓ USED / ✗ UNUSED status
- 📊 Generates `asset_report.md` automatically
- 🧹 Prompts to delete unused assets interactively

### Other Commands

```bash
# Analyze without prompting for cleanup
dart run asset_tree_shaker analyze

# Generate detailed report
dart run asset_tree_shaker report --format=markdown

# Remove unused assets (with confirmation)
dart run asset_tree_shaker clean

# CI/CD mode: fail if unused assets found
dart run asset_tree_shaker analyze --strict
```

## 📖 Commands

### 1. `check` ⭐ (Recommended)

**All-in-one analysis, reporting, and cleanup with interactive prompt.**

```bash
dart run asset_tree_shaker check [options]
```

**Options:**

```
  -p, --project      Path to Flutter project root (default: .)
  -o, --output       Output path for the report file (default: asset_report.md)
  -c, --config       Path to configuration file
  -v, --verbose      Enable verbose output
      --no-report    Skip generating report file
      --clean        Prompt to clean unused assets (default: on)
```

**Examples:**

```bash
# Full analysis with interactive cleanup
dart run asset_tree_shaker check

# Skip report generation
dart run asset_tree_shaker check --no-report

# Custom report filename
dart run asset_tree_shaker check -o my_report.md

# Custom project path
dart run asset_tree_shaker check -p ./my_flutter_project
```

### 2. `analyze`

**Analyze assets and report unused ones.**

```bash
dart run asset_tree_shaker analyze [options]
```

**Options:**

```
  -p, --project      Path to Flutter project root (default: .)
  -s, --strict       Fail with exit code 1 if unused assets found (for CI/CD)
  -c, --config       Path to configuration file
  -v, --verbose      Enable verbose output
```

**Examples:**

```bash
# Analyze current project
dart run asset_tree_shaker analyze

# Strict mode (for CI/CD pipelines)
dart run asset_tree_shaker analyze --strict

# Verbose output
dart run asset_tree_shaker analyze --verbose
```

### 3. `report`

**Generate a detailed asset usage report.**

```bash
dart run asset_tree_shaker report [options]
```

**Options:**

```
  -p, --project      Path to Flutter project root (default: .)
  -f, --format       Report format: markdown, json, html (default: markdown)
  -o, --output       Output file path
  -c, --config       Path to configuration file
```

**Examples:**

```bash
# Generate markdown report
dart run asset_tree_shaker report --format=markdown -o report.md

# Generate JSON report
dart run asset_tree_shaker report --format=json -o report.json

# Generate HTML report
dart run asset_tree_shaker report --format=html -o report.html
```

### 4. `clean`

**Remove unused assets from the project (with backup).**

```bash
dart run asset_tree_shaker clean [options]
```

**Options:**

```
  -p, --project           Path to Flutter project root (default: .)
  -f, --force             Skip confirmation prompt
  -d, --dry-run           Show what would be deleted without deleting
      --no-backup         Skip creating backup file
      --update-pubspec    Remove from pubspec.yaml too
  -c, --config            Path to configuration file
```

**Examples:**

```bash
# Clean with confirmation prompt
dart run asset_tree_shaker clean

# Force delete without prompt
dart run asset_tree_shaker clean --force

# Preview deletions without actually deleting
dart run asset_tree_shaker clean --dry-run

# Delete without creating backup
dart run asset_tree_shaker clean --force --no-backup
```

### 5. `init`

**Create a default configuration file (`asset_tree_shaker.yaml`).**

```bash
dart run asset_tree_shaker init [options]
```

**Options:**

```
  --force          Overwrite existing configuration
```

**Example:**

```bash
# Create default config
dart run asset_tree_shaker init

# Overwrite existing config
dart run asset_tree_shaker init --force
```

### 6. `restore`

**Restore assets from a backup file.**

```bash
dart run asset_tree_shaker restore [options]
```

**Options:**

```
  --from            Path to backup file (required)
```

**Example:**

```bash
# Restore from backup
dart run asset_tree_shaker restore --from=.asset_backup_2024-12-30.json
```

## ⚙️ Configuration

Create `asset_tree_shaker.yaml` in your project root to customize behavior:

```yaml
# Directories to scan for Dart files (relative to project root)
scan_paths:
          - lib/
          - test/

# Patterns to exclude from analysis (glob patterns)
exclude_patterns:
          - "assets/generated/**"
          - "assets/placeholders/**"
          - "assets/temp/**"

# Known dynamic patterns (runtime-loaded assets that can't be statically detected)
# Use glob patterns to match files at runtime
dynamic_patterns:
          - "assets/avatars/*.png"
          - "assets/locales/*.json"
          - "assets/themes/**/*.yaml"

# Strict mode: fail with exit code 1 if unused assets found
# Useful for CI/CD pipelines
strict_mode: false

# Report generation settings
generate_report: true
report_format: markdown # markdown, json, or html
report_output: asset_report.md
```

**Generate default config:**

```bash
dart run asset_tree_shaker init
```

This creates a complete `asset_tree_shaker.yaml` template with all available options.

## 🔧 Handling Dynamic Assets

Dynamic asset paths like `'assets/images/$userId.png'` can't be statically analyzed. Asset Tree Shaker handles this through:

### 1. Automatic Detection

```dart
// Detected: pattern "assets/images/*"
Image.asset('assets/images/${user.id}.png');
```

### 2. Configuration Whitelist

```yaml
dynamic_patterns:
          - "assets/avatars/*.png"
```

### 3. Annotations

```dart
import 'package:asset_tree_shaker/asset_tree_shaker.dart';

@KeepAsset('assets/images/splash.png')
class SplashScreen extends StatelessWidget { }

@KeepAssets(['assets/sounds/click.mp3', 'assets/sounds/success.mp3'])
class SoundManager { }
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
name: Asset Check

on: [push, pull_request]

jobs:
          asset-check:
                    runs-on: ubuntu-latest
                    steps:
                              - uses: actions/checkout@v3

                              - uses: dart-lang/setup-dart@v1
                                with:
                                          sdk: 3.0.0

                              - name: Install dependencies
                                run: dart pub get

                              - name: Check unused assets
                                run: dart run asset_tree_shaker analyze --strict
```

### GitLab CI

```yaml
asset-check:
          image: google/dart:latest
          script:
                    - dart pub get
                    - dart run asset_tree_shaker analyze --strict
```

### Local Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
dart run asset_tree_shaker analyze --strict
if [ $? -ne 0 ]; then
  echo "Commit aborted: Unused assets found"
  exit 1
fi
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

## 📚 Programmatic Usage (API)

Use Asset Tree Shaker in your own Dart code:

```dart
import 'package:asset_tree_shaker/asset_tree_shaker.dart';

Future<void> analyzeAssets() async {
  const projectRoot = '.';

  // 1. Discover all declared assets
  final discovery = AssetDiscovery(projectRoot: projectRoot);
  final declaredAssets = await discovery.discoverAssets();

  // 2. Scan for asset usage
  final config = await loadConfig(); // Load from asset_tree_shaker.yaml
  final scanner = UsageScanner(projectRoot: projectRoot, config: config);
  final scanResult = await scanner.scan();

  // 3. Analyze and compare
  final analyzer = GraphAnalyzer(config: config);
  final result = analyzer.analyze(
    declaredAssets: declaredAssets,
    scanResult: scanResult,
    projectRoot: projectRoot,
  );

  // 4. Use results
  print('Total assets: ${result.assets.length}');
  print('Unused assets: ${result.unusedAssets.length}');
  print('Potential savings: ${result.unusedSizeFormatted}');

  // 5. Generate reports
  final generator = ReportGenerator(result: result);
  final mdReport = generator.generate(ReportFormat.markdown);
  final jsonReport = generator.generate(ReportFormat.json);

  // 6. Clean up
  final cleaner = AssetCleaner(projectRoot: projectRoot);
  final cleanResult = await cleaner.clean(
    analysisResult: result,
    dryRun: false,
    createBackup: true,
  );

  print('Deleted: ${cleanResult.deletedAssets.length} assets');
}
```

## 📋 Exit Codes

| Code | Meaning                                               |
| ---- | ----------------------------------------------------- |
| 0    | Success                                               |
| 1    | Unused assets found (strict mode) or operation failed |
| 64   | Usage error (invalid arguments)                       |

## 📊 Output Examples

### Check Command Output

```
┌─────────────────────────────────────────────────────────────┐
│                 🌳 Asset Tree Shaker                        │
└─────────────────────────────────────────────────────────────┘

📂 Project: /Users/vansh/my_app

┌─────────────────────────────────────────────────────────────┐
│                     Asset Status                            │
├─────────────────────────────────────────────────────────────┤
│ ✗ UNUSED   assets/images/old_logo.png                12.5 KB
│ ✓ USED     assets/images/logo.png                     8.2 KB
│ ✓ USED     assets/fonts/Roboto.ttf                  156.0 KB
│ 📌 KEPT    assets/backgrounds/placeholder.png        45.3 KB
│ ⏭ DYNAMIC assets/avatars/default.png               102.1 KB
└─────────────────────────────────────────────────────────────┘

📊 Summary:
   ✅ Used:     3
   ❌ Unused:   1
   ⏭️  Skipped:  2

   💾 Total size:   323.1 KB
   🗑️  Unused size:  12.5 KB (3.9% savings)
```

## 🆘 Troubleshooting

### "No assets found"

- Check that your `pubspec.yaml` has an `assets:` section
- Verify asset paths are correct in `pubspec.yaml`

### "False positives - assets marked unused but are used"

Add to `asset_tree_shaker.yaml`:

```yaml
dynamic_patterns:
          - "assets/pattern/**"
```

Or use annotations in your code:

```dart
import 'package:asset_tree_shaker/asset_tree_shaker.dart';

@KeepAsset('assets/images/runtime_loaded.png')
class MyWidget {}
```

### "Large number of unused assets"

1. Run with `--verbose` to see detailed information
2. Check if assets were moved or renamed
3. Verify dynamic asset patterns in config

## 🤝 Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

For detailed guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with the Dart [analyzer](https://pub.dev/packages/analyzer) package
- Inspired by similar tools in other ecosystems (webpack, etc.)
- Thanks to the Flutter community for feedback and contributions

---

**Made with ❤️ by [Vansh Panchal](https://github.com/Vanshpanchal)**

[⬆ Back to top](#asset-tree-shaker-)
