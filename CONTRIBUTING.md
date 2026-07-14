# Contributing to Isle

Thanks for helping make Isle better. This project aims to stay small, focused, and easy to adopt in production iOS apps.

## Getting Started

1. Fork the repository.
2. Create a branch from `main`.
3. Open `Package.swift` in Xcode 15.3 or newer.
4. Make your change with focused commits.
5. Run the test suite before opening a pull request.

```sh
swift test
```

## Development Guidelines

- Keep Isle dependency-free unless there is a strong reason to change that.
- Prefer small, focused APIs over broad configuration surfaces.
- Preserve support for iOS 15+.
- Add or update tests when behavior changes.
- Update README examples when public API changes.
- Keep public symbols documented with concise Swift documentation comments.

## Pull Requests

Please include:

- A clear description of the problem and solution
- Screenshots or recordings for visual changes
- Notes about testing performed
- Any follow-up work that should happen separately

## Issues

Bug reports are most useful when they include:

- iOS version and device or simulator model
- Isle version or commit SHA
- Reproduction steps
- Expected behavior
- Actual behavior
- Screenshots or recordings, if visual

Feature requests are welcome. Please describe the use case first so the API can stay simple and generally useful.

## Release Notes

User-facing changes should be added to [CHANGELOG.md](CHANGELOG.md) under `Unreleased`.

## Code of Conduct

Be kind, specific, and constructive. Assume good intent, and help keep discussion focused on the project and the people using it.
