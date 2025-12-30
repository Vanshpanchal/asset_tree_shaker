# Contributing to Asset Tree Shaker

First off, thank you for considering contributing to Asset Tree Shaker! 🎉

## Code of Conduct

This project and everyone participating in it is governed by our commitment to creating a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **Environment details** (Dart/Flutter version, OS)
- **Code samples** or minimal reproduction if possible

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:

- **Clear title** describing the enhancement
- **Detailed description** of the proposed functionality
- **Use case** explaining why this would be useful
- **Possible implementation** if you have ideas

### Pull Requests

1. **Fork** the repository
2. **Create a branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes** with clear, descriptive commits
4. **Add tests** for new functionality
5. **Run tests** (`dart test`)
6. **Run analysis** (`dart analyze`)
7. **Submit a PR** with a clear description

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/asset_tree_shaker.git
cd asset_tree_shaker

# Get dependencies
dart pub get

# Run tests
dart test

# Run analysis
dart analyze

# Test the CLI
dart run asset_tree_shaker --help
```

## Style Guidelines

### Dart Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Run `dart format .` before committing
- Ensure `dart analyze` passes with no issues

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove, etc.)
- Reference issues when applicable (`Fix #123`)

### Documentation

- Add dartdoc comments for public APIs
- Update README.md for user-facing changes
- Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/)

## Testing

- Write tests for new features
- Maintain or improve code coverage
- Test edge cases and error conditions

```bash
# Run all tests
dart test

# Run specific test file
dart test test/ast_visitor_test.dart

# Run with coverage (requires coverage package)
dart test --coverage=coverage
```

## Project Structure

```
asset_tree_shaker/
├── bin/                    # CLI entry point
├── lib/
│   ├── asset_tree_shaker.dart  # Library exports
│   └── src/
│       ├── analyzer/       # Graph analysis logic
│       ├── annotations/    # @KeepAsset annotations
│       ├── cleaner/        # Asset deletion logic
│       ├── config/         # Configuration handling
│       ├── discovery/      # Asset discovery from pubspec
│       ├── reporter/       # Report generation
│       ├── scanner/        # AST-based code scanning
│       └── utils/          # Utility functions
├── test/                   # Test files
└── example/                # Example usage
```

## Questions?

Feel free to open an issue for questions or discussions. We're happy to help!

Thank you for contributing! 🙏
