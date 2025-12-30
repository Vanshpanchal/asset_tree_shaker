# Asset Tree Shaker - Technical Design Document

## 1. Executive Summary

**Asset Tree Shaker** is a build-time tool for Flutter projects that detects and optionally removes unused static assets (images, fonts, JSON files, etc.). It uses Abstract Syntax Tree (AST) analysis to accurately identify asset references in Dart code, providing a reliable alternative to regex-based approaches.

---

## 2. Problem Statement

### Current Pain Points
- Flutter apps accumulate unused assets over time
- `pubspec.yaml` becomes bloated with orphaned asset declarations
- No native Flutter tool for static asset tree-shaking
- Manual asset cleanup is error-prone and time-consuming
- Increased APK/IPA sizes due to bundled unused assets

### Goals
1. **Detect** all declared assets in `pubspec.yaml`
2. **Analyze** Dart source code using AST to find asset references
3. **Compare** declared vs. used assets to identify orphans
4. **Handle** edge cases (dynamic paths, generated code)
5. **Integrate** with CI/CD pipelines

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Asset Tree Shaker                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐ │
│  │   Config    │    │   Asset     │    │      Usage Scanner      │ │
│  │   Loader    │    │  Discovery  │    │     (AST Analyzer)      │ │
│  └──────┬──────┘    └──────┬──────┘    └───────────┬─────────────┘ │
│         │                  │                       │               │
│         └──────────────────┼───────────────────────┘               │
│                            ▼                                       │
│                  ┌─────────────────────┐                           │
│                  │   Graph Analyzer    │                           │
│                  │  (Compare & Match)  │                           │
│                  └──────────┬──────────┘                           │
│                             │                                      │
│              ┌──────────────┼──────────────┐                       │
│              ▼              ▼              ▼                       │
│       ┌───────────┐  ┌───────────┐  ┌───────────┐                 │
│       │  Report   │  │   Clean   │  │  CI/CD    │                 │
│       │ Generator │  │  Command  │  │  Checker  │                 │
│       └───────────┘  └───────────┘  └───────────┘                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Component Design

### 4.1 Configuration Loader (`ConfigLoader`)

**Responsibility:** Load and parse `asset_tree_shaker.yaml` configuration file.

**Features:**
- Default configuration fallback
- Whitelist patterns (glob support)
- Annotation-based exclusions
- Custom scan directories

**Configuration Schema:**
```yaml
# asset_tree_shaker.yaml
scan_paths:
  - lib/
  - test/

exclude_patterns:
  - "assets/generated/**"
  - "assets/placeholders/**"

keep_annotations:
  - "@KeepAsset"
  - "@PreserveAsset"

dynamic_patterns:
  - "assets/images/avatar_*.png"
  - "assets/locales/*.json"

strict_mode: false
generate_report: true
report_format: "markdown"  # markdown | json | html
```

---

### 4.2 Asset Discovery (`AssetDiscovery`)

**Responsibility:** Parse `pubspec.yaml` and enumerate all declared assets.

**Algorithm:**
1. Parse YAML structure
2. Extract `flutter.assets` list
3. Expand glob patterns to concrete file paths
4. Handle directory declarations (e.g., `assets/images/`)
5. Return normalized asset path set

**Data Structure:**
```dart
class DeclaredAsset {
  final String path;           // Normalized path
  final String originalDecl;   // Original pubspec declaration
  final bool isDirectory;      // Was declared as directory
  final bool isGlob;          // Contains glob pattern
}
```

---

### 4.3 Usage Scanner (`UsageScanner`)

**Responsibility:** Scan Dart files using AST analysis to find asset references.

**Why AST over Regex?**
- Regex cannot handle multi-line strings reliably
- Regex misses string concatenation patterns
- Regex has false positives in comments
- AST provides semantic understanding

**Scanning Strategy:**
```dart
// Detects these patterns:
Image.asset('assets/images/logo.png')        // Direct literal
AssetImage('assets/icons/home.svg')          // Constructor arg
rootBundle.loadString('assets/data.json')    // Bundle loading
'assets/images/' + imageName                  // Concatenation (flagged as dynamic)
'assets/images/${id}.png'                     // Interpolation (flagged as dynamic)
```

**AST Visitor Implementation:**
```dart
class AssetReferenceVisitor extends RecursiveAstVisitor<void> {
  final Set<String> foundAssets = {};
  final Set<String> dynamicPatterns = {};
  
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (_looksLikeAssetPath(node.value)) {
      foundAssets.add(node.value);
    }
  }
  
  @override
  void visitStringInterpolation(StringInterpolation node) {
    // Extract static prefix, flag as dynamic
    final prefix = _extractStaticPrefix(node);
    if (prefix != null && _looksLikeAssetPath(prefix)) {
      dynamicPatterns.add('$prefix*');
    }
  }
}
```

---

### 4.4 Graph Analyzer (`GraphAnalyzer`)

**Responsibility:** Compare declared assets against found usages.

**Algorithm:**
```
1. Load declared assets (D)
2. Load found usages (U)
3. Load whitelist patterns (W)
4. Load dynamic patterns (P)

5. For each asset in D:
   a. If asset ∈ U → USED
   b. If asset matches any pattern in W → WHITELISTED
   c. If asset matches any pattern in P → DYNAMIC_MATCH
   d. Else → UNUSED

6. Generate analysis result with categorization
```

**Output Structure:**
```dart
class AnalysisResult {
  final Set<String> usedAssets;
  final Set<String> unusedAssets;
  final Set<String> whitelistedAssets;
  final Set<String> dynamicMatchAssets;
  final List<DynamicUsageWarning> warnings;
}
```

---

### 4.5 Annotation System

**Custom Annotation Definition:**
```dart
/// Marks an asset as required, preventing tree-shaker removal.
/// 
/// Usage:
/// ```dart
/// @KeepAsset('assets/images/splash.png')
/// class SplashScreen extends StatelessWidget {}
/// ```
class KeepAsset {
  final String assetPath;
  const KeepAsset(this.assetPath);
}

/// Marks multiple assets or a pattern as required.
class KeepAssets {
  final List<String> assetPaths;
  const KeepAssets(this.assetPaths);
}
```

**AST Detection:**
The scanner detects annotations and extracts asset paths from them.

---

### 4.6 Dynamic Usage Detection

**Challenge:** Dynamic asset paths like `'assets/images/$id.png'` cannot be statically resolved.

**Solution - Multi-layer approach:**

1. **Static Prefix Extraction**
   ```dart
   'assets/images/${userId}.png' → prefix: 'assets/images/'
   ```

2. **Pattern Inference**
   - Group assets by directory
   - If directory has partial usage, flag remaining as "potentially dynamic"

3. **Configuration Whitelist**
   ```yaml
   dynamic_patterns:
     - "assets/avatars/*.png"  # Known dynamic set
   ```

4. **Warning System**
   ```
   ⚠️  Dynamic asset reference detected at lib/screens/profile.dart:42
       Pattern: 'assets/images/${...}.png'
       Consider adding to dynamic_patterns in config.
   ```

---

## 5. CLI Interface

### Commands

```bash
# Analyze and report (dry-run)
dart run asset_tree_shaker analyze

# Analyze with strict mode (fail on unused)
dart run asset_tree_shaker analyze --strict

# Clean unused assets (with confirmation)
dart run asset_tree_shaker clean

# Clean without confirmation
dart run asset_tree_shaker clean --force

# Generate detailed report
dart run asset_tree_shaker report --format=markdown --output=asset_report.md

# Initialize configuration file
dart run asset_tree_shaker init
```

### Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success, no unused assets |
| 1 | Unused assets found (strict mode) |
| 2 | Configuration error |
| 3 | File system error |

---

## 6. CI/CD Integration

### GitHub Actions Example
```yaml
- name: Check Unused Assets
  run: dart run asset_tree_shaker analyze --strict
```

### GitLab CI Example
```yaml
asset-check:
  script:
    - dart run asset_tree_shaker analyze --strict
  allow_failure: false
```

### Report Artifact Generation
```yaml
- name: Generate Asset Report
  run: dart run asset_tree_shaker report --format=json --output=asset-report.json
- uses: actions/upload-artifact@v3
  with:
    name: asset-report
    path: asset-report.json
```

---

## 7. Safety Mechanisms

### 7.1 Pre-deletion Checklist
1. ✅ Asset not in found usages
2. ✅ Asset not in whitelist
3. ✅ Asset not matching dynamic patterns
4. ✅ Asset not annotated with `@KeepAsset`
5. ✅ User confirmation (unless `--force`)

### 7.2 Backup System
```dart
// Before deletion, create backup manifest
{
  "timestamp": "2024-01-15T10:30:00Z",
  "deleted_assets": [
    {"path": "assets/old_logo.png", "hash": "abc123..."}
  ],
  "restore_command": "dart run asset_tree_shaker restore --from=.asset_backup_20240115.json"
}
```

### 7.3 Dry-Run Default
- Default mode is analysis-only
- Deletion requires explicit `clean` command
- `--force` required for non-interactive environments

---

## 8. Edge Cases & Mitigations

| Edge Case | Detection | Mitigation |
|-----------|-----------|------------|
| Dynamic paths (`$variable`) | String interpolation visitor | Extract prefix, warn, suggest whitelist |
| Concatenation (`'path/' + name`) | Binary expression visitor | Extract static parts, warn |
| Conditional assets | Control flow analysis | Conservative: mark as potentially used |
| Generated code | `.g.dart` file detection | Include in scan by default |
| Test-only assets | Configurable scan paths | Include `test/` in config |
| Asset references in comments | AST ignores comments | No false positives |
| Multi-package monorepo | Package-aware scanning | Respect package boundaries |

---

## 9. Performance Considerations

### Incremental Analysis
- Cache AST parse results
- Hash-based change detection
- Only re-scan modified files

### Parallel Processing
```dart
// Parallel file scanning
final results = await Future.wait(
  dartFiles.map((file) => _scanFile(file)),
);
```

### Memory Efficiency
- Stream-based file reading
- Dispose AST nodes after visiting
- Limit concurrent file handles

---

## 10. Future Enhancements

1. **IDE Integration** - VS Code extension for real-time unused asset highlighting
2. **Build Runner Integration** - `build.yaml` configuration support
3. **Asset Compression Suggestions** - Identify oversized assets
4. **Duplicate Detection** - Find identical assets with different names
5. **Usage Statistics** - Track asset usage frequency across codebase

---

## 11. Dependencies

```yaml
dependencies:
  analyzer: ^6.0.0      # AST parsing
  glob: ^2.1.0          # Pattern matching
  yaml: ^3.1.0          # YAML parsing
  args: ^2.4.0          # CLI argument parsing
  path: ^1.8.0          # Path manipulation
  crypto: ^3.0.0        # File hashing for backup
  
dev_dependencies:
  test: ^1.24.0
  mockito: ^5.4.0
```

---

## 12. File Structure

```
asset_tree_shaker/
├── bin/
│   └── asset_tree_shaker.dart      # CLI entry point
├── lib/
│   ├── asset_tree_shaker.dart      # Library export
│   ├── src/
│   │   ├── config/
│   │   │   ├── config.dart
│   │   │   └── config_loader.dart
│   │   ├── discovery/
│   │   │   └── asset_discovery.dart
│   │   ├── scanner/
│   │   │   ├── usage_scanner.dart
│   │   │   └── ast_visitor.dart
│   │   ├── analyzer/
│   │   │   └── graph_analyzer.dart
│   │   ├── reporter/
│   │   │   ├── report_generator.dart
│   │   │   └── formats/
│   │   │       ├── markdown_format.dart
│   │   │       ├── json_format.dart
│   │   │       └── html_format.dart
│   │   ├── cleaner/
│   │   │   └── asset_cleaner.dart
│   │   ├── annotations/
│   │   │   └── keep_asset.dart
│   │   └── utils/
│   │       ├── file_utils.dart
│   │       └── pattern_matcher.dart
│   └── src/
├── test/
│   ├── discovery_test.dart
│   ├── scanner_test.dart
│   ├── analyzer_test.dart
│   └── integration_test.dart
├── example/
│   └── asset_tree_shaker.yaml
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
└── TDD.md
```

---

## 13. Acceptance Criteria

- [ ] Correctly parses all asset declarations from `pubspec.yaml`
- [ ] Identifies 100% of static string literal asset references
- [ ] Flags dynamic asset patterns with actionable warnings
- [ ] Respects whitelist and annotation exclusions
- [ ] Generates accurate reports in multiple formats
- [ ] Fails CI build in strict mode when unused assets exist
- [ ] Safely deletes assets with backup/restore capability
- [ ] Performs analysis in under 10 seconds for medium projects (500 files)
