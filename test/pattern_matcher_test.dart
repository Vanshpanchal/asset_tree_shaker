import 'package:test/test.dart';

import 'package:asset_tree_shaker/src/utils/pattern_matcher.dart';

void main() {
  group('PatternMatcher', () {
    test('matches exclude patterns', () {
      final matcher = PatternMatcher(
        excludePatterns: ['assets/generated/**', 'assets/test/*.png'],
        dynamicPatterns: [],
      );

      expect(
          matcher.matchesExcludePattern('assets/generated/file.png'), isTrue);
      expect(matcher.matchesExcludePattern('assets/generated/sub/file.png'),
          isTrue);
      expect(matcher.matchesExcludePattern('assets/test/image.png'), isTrue);
      expect(matcher.matchesExcludePattern('assets/images/logo.png'), isFalse);
    });

    test('matches dynamic patterns', () {
      final matcher = PatternMatcher(
        excludePatterns: [],
        dynamicPatterns: ['assets/avatars/*.png', 'assets/levels/level_*.json'],
      );

      expect(matcher.matchesDynamicPattern('assets/avatars/user1.png'), isTrue);
      expect(matcher.matchesDynamicPattern('assets/avatars/user2.png'), isTrue);
      expect(
          matcher.matchesDynamicPattern('assets/levels/level_1.json'), isTrue);
      expect(
          matcher.matchesDynamicPattern('assets/levels/level_99.json'), isTrue);
      expect(matcher.matchesDynamicPattern('assets/images/logo.png'), isFalse);
    });

    test('returns matching pattern', () {
      final matcher = PatternMatcher(
        excludePatterns: ['assets/generated/**'],
        dynamicPatterns: ['assets/avatars/*.png'],
      );

      expect(
        matcher.getMatchingExcludePattern('assets/generated/file.png'),
        equals('assets/generated/**'),
      );
      expect(
        matcher.getMatchingDynamicPattern('assets/avatars/user.png'),
        equals('assets/avatars/*.png'),
      );
    });
  });

  group('PatternMatcher static methods', () {
    test('matchesSimplePattern with *', () {
      expect(
        PatternMatcher.matchesSimplePattern(
            'assets/images/logo.png', 'assets/images/*.png'),
        isTrue,
      );
      expect(
        PatternMatcher.matchesSimplePattern(
            'assets/images/icon.svg', 'assets/images/*.png'),
        isFalse,
      );
    });

    test('matchesSimplePattern with **', () {
      expect(
        PatternMatcher.matchesSimplePattern(
            'assets/a/b/c/file.png', 'assets/**/file.png'),
        isTrue,
      );
      expect(
        PatternMatcher.matchesSimplePattern(
            'assets/sub/file.png', 'assets/**/file.png'),
        isTrue,
      );
    });

    test('matchesSimplePattern with ?', () {
      expect(
        PatternMatcher.matchesSimplePattern(
            'assets/icon_a.png', 'assets/icon_?.png'),
        isTrue,
      );
      expect(
        PatternMatcher.matchesSimplePattern(
            'assets/icon_ab.png', 'assets/icon_?.png'),
        isFalse,
      );
    });

    test('extractStaticPrefix', () {
      expect(
        PatternMatcher.extractStaticPrefix('assets/images/*.png'),
        equals('assets/images/'),
      );
      expect(
        PatternMatcher.extractStaticPrefix('assets/levels/level_?.json'),
        equals('assets/levels/level_'),
      );
      expect(
        PatternMatcher.extractStaticPrefix('assets/images/logo.png'),
        equals('assets/images/logo.png'),
      );
    });

    test('extractStaticSuffix', () {
      expect(
        PatternMatcher.extractStaticSuffix('assets/images/*.png'),
        equals('.png'),
      );
      expect(
        PatternMatcher.extractStaticSuffix('assets/images/*'),
        isNull,
      );
    });

    test('groupByDirectory', () {
      final paths = [
        'assets/images/logo.png',
        'assets/images/icon.png',
        'assets/sounds/click.mp3',
      ];

      final groups = PatternMatcher.groupByDirectory(paths);

      expect(groups['assets/images'], hasLength(2));
      expect(groups['assets/sounds'], hasLength(1));
    });

    test('inferPattern from similar paths', () {
      final paths = [
        'assets/avatars/avatar_1.png',
        'assets/avatars/avatar_2.png',
        'assets/avatars/avatar_3.png',
      ];

      final pattern = PatternMatcher.inferPattern(paths);

      expect(pattern, equals('assets/avatars/avatar_*.png'));
    });

    test('inferPattern returns null for dissimilar paths', () {
      final paths = [
        'images/logo.png',
        'sounds/click.mp3',
        'data/config.json',
      ];

      final pattern = PatternMatcher.inferPattern(paths);

      // These have no meaningful common prefix
      expect(pattern, isNull);
    });
  });
}
