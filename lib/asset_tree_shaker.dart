/// Asset Tree Shaker - Detect and remove unused assets from Flutter projects.
///
/// This library provides tools to:
/// - Discover all declared assets in pubspec.yaml
/// - Scan Dart files using AST analysis to find asset references
/// - Compare declared vs used assets to identify orphans
/// - Generate reports and optionally clean unused assets
library asset_tree_shaker;

// Configuration
export 'src/config/config.dart';
export 'src/config/config_loader.dart';

// Asset Discovery
export 'src/discovery/asset_discovery.dart';

// Usage Scanner
export 'src/scanner/usage_scanner.dart';
export 'src/scanner/ast_visitor.dart';

// Graph Analyzer
export 'src/analyzer/graph_analyzer.dart';
export 'src/analyzer/analysis_result.dart';

// Reporter
export 'src/reporter/report_generator.dart';

// Cleaner
export 'src/cleaner/asset_cleaner.dart';

// Annotations
export 'src/annotations/keep_asset.dart';

// Utils
export 'src/utils/pattern_matcher.dart';
