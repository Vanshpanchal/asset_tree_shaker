/// Annotation to mark an asset as required, preventing tree-shaker removal.
///
/// Use this annotation when an asset is used dynamically or through a pattern
/// that the static analyzer cannot detect.
///
/// Example:
/// ```dart
/// @KeepAsset('assets/images/splash.png')
/// class SplashScreen extends StatelessWidget {
///   // Asset is used dynamically or via a method the analyzer can't trace
/// }
/// ```
class KeepAsset {
  /// The asset path to preserve.
  final String assetPath;

  /// Creates a KeepAsset annotation.
  const KeepAsset(this.assetPath);
}

/// Annotation to mark multiple assets as required.
///
/// Use this when you need to preserve several assets that are used dynamically.
///
/// Example:
/// ```dart
/// @KeepAssets([
///   'assets/images/avatar_default.png',
///   'assets/images/avatar_guest.png',
/// ])
/// class AvatarService {
///   // These assets are loaded based on user state
/// }
/// ```
class KeepAssets {
  /// The list of asset paths to preserve.
  final List<String> assetPaths;

  /// Creates a KeepAssets annotation.
  const KeepAssets(this.assetPaths);
}

/// Annotation to preserve all assets matching a pattern.
///
/// Use glob-style patterns to preserve groups of related assets.
///
/// Example:
/// ```dart
/// @PreserveAsset('assets/locales/*.json')
/// class LocalizationService {
///   // Locale files are loaded based on device settings
/// }
/// ```
class PreserveAsset {
  /// The glob pattern for assets to preserve.
  final String pattern;

  /// Creates a PreserveAsset annotation.
  const PreserveAsset(this.pattern);
}
