# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2024-12-30

### Changed

- Updated author email to vansh.panchal7@proton.me

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
