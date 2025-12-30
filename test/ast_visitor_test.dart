import 'package:test/test.dart';

import 'package:asset_tree_shaker/src/scanner/ast_visitor.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

void main() {
  group('AssetReferenceVisitor', () {
    test('detects simple string literal asset paths', () {
      const code = '''
        void main() {
          final image = Image.asset('assets/images/logo.png');
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, contains('assets/images/logo.png'));
    });

    test('detects AssetImage constructor', () {
      const code = '''
        void main() {
          final decoration = BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/backgrounds/gradient.png'),
            ),
          );
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, contains('assets/backgrounds/gradient.png'));
    });

    test('detects rootBundle.loadString', () {
      const code = '''
        Future<void> loadConfig() async {
          final json = await rootBundle.loadString('assets/config/settings.json');
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, contains('assets/config/settings.json'));
    });

    test('ignores non-asset string literals', () {
      const code = '''
        void main() {
          final message = 'Hello, world!';
          final url = 'https://example.com';
          final path = '/home/user/document.txt';
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, isEmpty);
    });

    test('ignores asset paths in comments', () {
      const code = '''
        void main() {
          // This is a comment: assets/images/old.png
          /* Also: assets/icons/deprecated.svg */
          final image = Image.asset('assets/images/current.png');
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, hasLength(1));
      expect(result.staticAssets, contains('assets/images/current.png'));
      expect(result.staticAssets, isNot(contains('assets/images/old.png')));
      expect(
          result.staticAssets, isNot(contains('assets/icons/deprecated.svg')));
    });

    test('detects string interpolation and creates dynamic reference', () {
      const code = r'''
        void loadAvatar(String id) {
          final path = 'assets/avatars/${id}.png';
        }
      ''';

      final result = _scanCode(code);

      expect(result.dynamicReferences, isNotEmpty);
      expect(result.dynamicReferences.first.staticPrefix,
          equals('assets/avatars/'));
      expect(result.dynamicReferences.first.staticSuffix, equals('.png'));
    });

    test('detects string concatenation and creates dynamic reference', () {
      const code = '''
        void loadLevel(int level) {
          final path = 'assets/levels/' + level.toString() + '.json';
        }
      ''';

      final result = _scanCode(code);

      expect(result.dynamicReferences, isNotEmpty);
      expect(result.dynamicReferences.first.staticPrefix,
          equals('assets/levels/'));
    });

    test('detects adjacent strings', () {
      const code = '''
        void main() {
          final path = 'assets/images/' 'background.png';
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, contains('assets/images/background.png'));
    });

    test('detects multiple assets in same file', () {
      const code = '''
        void main() {
          final logo = Image.asset('assets/images/logo.png');
          final icon = AssetImage('assets/icons/home.svg');
          final config = 'assets/data/config.json';
        }
      ''';

      final result = _scanCode(code);

      expect(result.staticAssets, hasLength(3));
      expect(result.staticAssets, contains('assets/images/logo.png'));
      expect(result.staticAssets, contains('assets/icons/home.svg'));
      expect(result.staticAssets, contains('assets/data/config.json'));
    });

    test('detects KeepAsset annotation', () {
      const code = '''
        @KeepAsset('assets/images/splash.png')
        class SplashScreen {
        }
      ''';

      final result = _scanCode(code);

      expect(result.annotatedAssets, contains('assets/images/splash.png'));
    });

    test('detects KeepAssets annotation with list', () {
      const code = '''
        @KeepAssets([
          'assets/sounds/click.mp3',
          'assets/sounds/success.mp3',
        ])
        class SoundManager {
        }
      ''';

      final result = _scanCode(code);

      expect(result.annotatedAssets, contains('assets/sounds/click.mp3'));
      expect(result.annotatedAssets, contains('assets/sounds/success.mp3'));
    });

    test('handles packages/ prefix', () {
      const code = '''
        void main() {
          final icon = Image.asset('packages/my_package/assets/icon.png');
        }
      ''';

      final result = _scanCode(code);

      expect(
          result.staticAssets, contains('packages/my_package/assets/icon.png'));
    });

    test('handles paths with escaped backslashes', () {
      const code = '''
        void main() {
          final path = 'assets\\\\images\\\\logo.png';
        }
      ''';

      final result = _scanCode(code);

      // After Dart string processing, this becomes assets\images\logo.png
      // which gets normalized to assets/images/logo.png
      expect(result.staticAssets, contains('assets/images/logo.png'));
    });
  });
}

AssetVisitorResult _scanCode(String code) {
  final parseResult = parseString(
    content: code,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  final visitor = AssetReferenceVisitor(
    sourceFile: 'test.dart',
  );

  parseResult.unit.visitChildren(visitor);

  return visitor.result;
}
