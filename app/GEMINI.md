# Detooz Flutter App

This is the Flutter mobile app for Detooz scam detection.

## Directory Structure

- `lib/ui/screens` - App screens
- `lib/ui/components` - Reusable widgets
- `lib/services` - Backend services (API, translation, ML)
- `lib/contracts` - Data models

## ⚠️ CRITICAL: Translation Rules

This app supports multiple languages. **ALL user-visible text must be translatable.**

### Rules When Adding UI:

1. **Use `Tr('...')` instead of `Text('...')`** for all visible text
2. **Use `tr('...')` for string parameters** like `label:`, `hintText:`, `title:`
3. **Watch `languageProvider`** in any screen using `tr()`:
   ```dart
   ref.watch(languageProvider);
   ```
4. **Add new strings to preload list** in `lib/ui/providers.dart` (search for `preloadTranslations`)
5. **In custom builder methods**, always use `tr(label)` not raw `label`

### After Adding New UI:
Run: `python migrate_to_tr.py lib`

See `TRANSLATION_GUIDE.md` for full details.

## Key Files

- `lib/ui/components/tr.dart` - Translation widgets (Tr, tr, TrBuilder)
- `lib/ui/providers.dart` - State management and preload list
- `migrate_to_tr.py` - Auto-migration script
