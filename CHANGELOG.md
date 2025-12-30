# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.2] - 2024-12-30

### Added

- **Complete Documentation** - Updated README.md with all commands and proper version references
- **Changelog Documentation** - Full list of available commands in CHANGELOG

### Changed

- Updated installation version reference to ^1.1.0
- Reorganized README with `check` command as primary recommendation
- Added detailed examples for all command options

---

## [1.1.1] - 2024-12-30

### Added

- **Comprehensive Documentation** - Updated README with all commands and version numbers
- **Author Information** - Added author email (vansh.panchal7@proton.me)

### Commands Available (v1.1.1)

- `check` - All-in-one analysis, reporting, and cleanup with interactive prompt
- `analyze` - Analyze and report unused assets
- `report` - Generate detailed reports (Markdown, JSON, HTML)
- `clean` - Remove unused assets with backup
- `init` - Create default configuration
- `restore` - Restore from backup

---

## [1.1.0] - 2024-12-30

### Added

- **New `check` Command** - All-in-one command for asset analysis
     - Shows all assets with visual used/unused status indicators
     - Displays file sizes and colored status labels
     - Automatically generates markdown report
     - Interactive prompt to clean unused assets
     - Summary with potential savings

---

## [1.0.0] - 2024-12-30

### Added

- **Asset Discovery** - Parse `pubspec.yaml` to list all declared assets

     - Support for direct file paths
     - Support for directory declarations (trailing `/`)
     - Support for glob patterns (`*.png`, `**/*.json`)

- **AST-Based Usage Scanner** - Scan Dart files using the `analyzer` package

     - Detect string literals matching asset paths
     - Detect string interpolation (`'assets/$name.png'`)
     - Detect string concatenation (`'assets/' + name + '.png'`)
     - Detect adjacent strings (`'assets/' 'image.png'`)
     - Ignore asset references in comments

- **Graph Analysis** - Compare declared vs. used assets

     - Identify unused assets
     - Support for whitelist patterns via configuration
     - Support for dynamic pattern matching
     - Support for `@KeepAsset` annotations

- **Report Generation** - Multiple output formats

     - Markdown reports
     - JSON reports (for CI/CD integration)
     - HTML reports (for visual review)

- **Asset Cleaning** - Safely remove unused assets

     - Dry-run mode for preview
     - Automatic backup before deletion
     - Restore command for recovery
     - Optional pubspec.yaml cleanup

- **CLI Tool** - Full-featured command-line interface

     - `analyze` - Detect unused assets
     - `clean` - Remove unused assets
     - `report` - Generate detailed reports
     - `init` - Create configuration file
     - `restore` - Recover from backup

- **CI/CD Integration** - Strict mode for build pipelines

     - Exit code 1 when unused assets found
     - JSON output for automated processing

- **Configuration System** - YAML-based configuration
     - Customizable scan paths
     - Exclude patterns (glob)
     - Dynamic patterns (glob)
     - Annotation configuration
