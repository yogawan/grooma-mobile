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
- Primary: `#0F766E`
- Primary Hover: `#115E59`
- Primary Light: `#CCFBF1`
- On Primary: `#FFFFFF`
- Background: `#F8FAFC`
- Surface: `#FFFFFF`
- Secondary Surface: `#E2E8F0`
- Foreground: `#0F172A`
- Muted: `#64748B`
- Primary Text: `#0F172A`
- Secondary Text: `#64748B`
- Border: `#E2E8F0`
- Success: `#16A34A`
- Warning: `#F59E0B`
- Danger / Error: `#DC2626`
- Info: `#2563EB`

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
