# Asset Tree Shaker 🌳

[![Pub Version](https://img.shields.io/pub/v/asset_tree_shaker)](https://pub.dev/packages/asset_tree_shaker)
[![Dart CI](https://github.com/Vanshpanchal/asset_tree_shaker/actions/workflows/ci.yml/badge.svg)](https://github.com/Vanshpanchal/asset_tree_shaker/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![pub points](https://img.shields.io/pub/points/asset_tree_shaker)](https://pub.dev/packages/asset_tree_shaker/score)

A build-time tool that **detects and removes unused assets** from Flutter projects. Uses AST (Abstract Syntax Tree) analysis to accurately identify asset references in Dart code.

## ✨ Features

- 🔍 **Smart Detection** - AST-based scanning (not just regex) for accurate results
- 📊 **Detailed Reports** - Generate Markdown, JSON, or HTML reports
- 🛡️ **Safe Deletion** - Automatic backup before removing assets
- ⚡ **CI/CD Ready** - Strict mode for build pipelines
- 🎯 **Dynamic Asset Support** - Handles interpolated paths with whitelist patterns
- 📝 **Annotation Support** - `@KeepAsset` to preserve specific assets

## 📦 Installation

Add to your `dev_dependencies`:

```yaml
dev_dependencies:
          asset_tree_shaker: ^1.1.0
```

Or install globally:

```bash
dart pub global activate asset_tree_shaker
```

## 🚀 Quick Start

```bash
# All-in-one: analyze, show status, generate report, and optionally clean
dart run asset_tree_shaker check

# Analyze your project
dart run asset_tree_shaker analyze

# Generate a detailed report
dart run asset_tree_shaker report --format=markdown

# Remove unused assets (with confirmation)
dart run asset_tree_shaker clean

# CI/CD mode: fail if unused assets found
dart run asset_tree_shaker analyze --strict
```

## 📖 Commands

### `check` ⭐ (Recommended)

All-in-one command: analyze assets, display status, generate report, and optionally clean.

```bash
dart run asset_tree_shaker check [options]

Options:
  -p, --project     Path to Flutter project root (default: .)
  -o, --output      Output path for the report file (default: asset_report.md)
  -c, --config      Path to configuration file
  -v, --verbose     Enable verbose output
      --no-report   Skip generating report file
      --clean       Prompt to clean unused assets (default: on)
```

**Example:**

```bash
# Full analysis with interactive cleanup prompt
dart run asset_tree_shaker check

# Skip report generation
dart run asset_tree_shaker check --no-report

# Custom report name
dart run asset_tree_shaker check -o my_assets_report.md
```

### `analyze`

Analyze assets and report unused ones.

```bash
dart run asset_tree_shaker analyze [options]

Options:
  -p, --project     Path to Flutter project root (default: .)
  -s, --strict      Fail with exit code 1 if unused assets found
  -v, --verbose     Enable verbose output
```

### `clean`

Remove unused assets from the project.

```bash
dart run asset_tree_shaker clean [options]

Options:
  -f, --force         Skip confirmation prompt
  -d, --dry-run       Show what would be deleted
      --no-backup     Skip creating backup file
      --update-pubspec  Remove from pubspec.yaml too
```

### `report`

Generate a detailed asset usage report.

```bash
dart run asset_tree_shaker report [options]

Options:
  -f, --format    Report format: markdown, json, html (default: markdown)
  -o, --output    Output file path
```

### `init`

Create a default configuration file.

```bash
dart run asset_tree_shaker init [--force]
```

### `restore`

Restore assets from a backup file.

```bash
dart run asset_tree_shaker restore --from=.asset_backup_2024-01-15.json
```

## ⚙️ Configuration

Create `asset_tree_shaker.yaml` in your project root:

```yaml
# Directories to scan for Dart files
scan_paths:
          - lib/

# Patterns to exclude from analysis
exclude_patterns:
          - "assets/generated/**"
          - "assets/placeholders/**"

# Known dynamic patterns (for runtime-loaded assets)
dynamic_patterns:
          - "assets/avatars/*.png"
          - "assets/locales/*.json"

# CI/CD: fail on unused assets
strict_mode: false

# Report settings
generate_report: true
report_format: markdown
```

Run `dart run asset_tree_shaker init` to generate a complete configuration template.

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
- name: Check Unused Assets
  run: dart run asset_tree_shaker analyze --strict
```

### GitLab CI

```yaml
asset-check:
          script:
                    - dart run asset_tree_shaker analyze --strict
```

## 📚 API Usage

Use Asset Tree Shaker programmatically:

```dart
import 'package:asset_tree_shaker/asset_tree_shaker.dart';

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

print('Unused assets: ${result.unusedAssets.length}');
```

## 📋 Exit Codes

| Code | Meaning                                               |
| ---- | ----------------------------------------------------- |
| 0    | Success                                               |
| 1    | Unused assets found (strict mode) or operation failed |
| 64   | Usage error (invalid arguments)                       |

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with the Dart [analyzer](https://pub.dev/packages/analyzer) package
- Inspired by the need for cleaner Flutter apps
