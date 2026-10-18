# Flutter Project Guidelines

## Tech Stack
- Flutter & Dart
- Material 3
- Font: Plus Jakarta Sans

## Folder Structure
```text
lib/
├── main.dart
├── app.dart
├── theme/
│   ├── app_colors.dart
│   └── app_theme.dart
├── screens/
├── widgets/
├── models/
└── services/
```

## Global Color Tokens
- Background: `#EEEEEE`
- Primary: `#171717`
- On Primary: `#FFFFFF`
- Surface: `#FFFFFF`
- Secondary Surface: `#E5E5E5`
- Primary Text: `#171717`
- Secondary Text: `#525252`
- Border: `#D4D4D4`
- Success: `#15803D`
- Warning: `#A16207`
- Error: `#B91C1C`
- Info: `#1D4ED8`

## Typography
- Use Plus Jakarta Sans globally.
- Apply typography through `ThemeData`.
- Keep font styles consistent across all screens.

## Development
- Centralize colors and themes in `lib/theme/`.
- Keep widgets reusable and code simple.
- Use null safety and `const` where appropriate.
- Avoid unnecessary dependencies and abstractions.
- Inspect existing code before modifying it.
- Preserve unrelated functionality.

## Verification
Run after changes:
```bash
dart format .
flutter analyze
flutter test
```

## Claude Code
- Follow the existing project structure.
- Make minimal, targeted changes.
- Never claim tests passed without running them.
- Ask before destructive changes.
