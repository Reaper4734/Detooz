# Translation Guidelines

This app supports multiple languages. **All user-visible text must be translatable.**

## Quick Rules

### ✅ DO: Use `Tr()` Widget for Text Widgets
```dart
// ✅ CORRECT
Tr('Hello World', style: TextStyle(fontSize: 16))

// ❌ WRONG - Text won't translate
Text('Hello World', style: TextStyle(fontSize: 16))
```

### ✅ DO: Use `tr()` Function for String Parameters
```dart
// ✅ CORRECT
BottomNavigationBarItem(label: tr('Home'))
ElevatedButton(child: Text(tr('Submit')))
FilterChip(label: Text(tr('High Risk')))

// ❌ WRONG - Labels won't translate
BottomNavigationBarItem(label: 'Home')
```

### ✅ DO: Watch `languageProvider` in Widgets Using `tr()`
```dart
class MyScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    // REQUIRED: Enables rebuild when translations load
    ref.watch(languageProvider);
    
    return Text(tr('My Label')); // Now this will translate!
  }
}
```

### ✅ DO: Add New Strings to Preload List
When you add new strings that use `tr()`, add them to `lib/ui/providers.dart`:

```dart
// In LanguageNotifier._initLanguage() and setLanguage()
await TranslationService().preloadTranslations([
  // ... existing strings ...
  'Your New String Here',  // ADD NEW STRINGS
]);
```

## Summary Table

| Widget Type | Use This |
|-------------|----------|
| `Text('...')` | `Tr('...')` |
| `label: '...'` | `label: tr('...')` |
| `hintText: '...'` | `hintText: tr('...')` |
| `title: '...'` | `title: tr('...')` |
| Custom builder methods | Pass through `tr(label)` in the Text widget |

## Custom Builder Methods

If you create helper methods like `_buildTab(String label)`:

```dart
Widget _buildTab(String label) {
  return Text(tr(label)); // ✅ Always wrap with tr()
}
```

## After Adding New UI

1. Run the migration script: `python migrate_to_tr.py lib`
2. Check if any `tr()` strings need adding to preload list
3. Test with Hindi language selected

## Files to Know

- `lib/ui/components/tr.dart` - Translation widgets
- `lib/ui/providers.dart` - Preload list (search for `preloadTranslations`)
- `migrate_to_tr.py` - Auto-migration script
