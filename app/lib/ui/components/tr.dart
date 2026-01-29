import 'package:flutter/material.dart';
import '../../services/translation/translation_service.dart';

/// Translatable Text widget
/// Simply replace Text('Hello') with Tr('Hello') to enable translation
/// 
/// Example:
/// ```dart
/// // Before
/// Text('Dashboard', style: TextStyle(fontSize: 24))
/// 
/// // After
/// Tr('Dashboard', style: TextStyle(fontSize: 24))
/// ```
class Tr extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;

  const Tr(
    this.text, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textDirection,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: TranslationService().translate(text),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
          textDirection: textDirection,
        );
      },
    );
  }
}

/// Translatable Text widget with placeholder support
/// 
/// Example:
/// ```dart
/// TrBuilder(
///   'Hello {name}, you have {count} messages',
///   args: {'name': 'John', 'count': '5'},
/// )
/// // Output (in Hindi): नमस्ते John, आपके पास 5 संदेश हैं
/// ```
class TrBuilder extends StatelessWidget {
  final String text;
  final Map<String, String> args;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TrBuilder(
    this.text, {
    required this.args,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _translateWithArgs(),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? _replaceArgs(text),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  Future<String> _translateWithArgs() async {
    // First translate the template
    final translated = await TranslationService().translate(text);
    // Then replace placeholders
    return _replaceArgs(translated);
  }

  String _replaceArgs(String template) {
    var result = template;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}

/// Extension for easy string translation
/// 
/// Example:
/// ```dart
/// final greeting = await 'Hello World'.tr;
/// ```
extension TrString on String {
  Future<String> get tr => TranslationService().translate(this);
}

/// Global sync translation function for String parameters
/// Use for: label:, hintText:, tooltip:, etc.
/// 
/// Example:
/// ```dart
/// BottomNavigationBarItem(
///   icon: Icon(Icons.home),
///   label: tr('Home'),  // Synchronous!
/// )
/// ```
String tr(String text) => TranslationService().translateSync(text);

/// Batch translation helper widget
/// Useful when you need multiple translations at once
/// 
/// Example:
/// ```dart
/// TrBatch(
///   texts: ['Dashboard', 'History', 'Settings'],
///   builder: (translations) {
///     return Row(
///       children: translations.map((t) => Text(t)).toList(),
///     );
///   },
/// )
/// ```
class TrBatch extends StatelessWidget {
  final List<String> texts;
  final Widget Function(List<String> translated) builder;

  const TrBatch({
    required this.texts,
    required this.builder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: TranslationService().translateBatch(texts),
      builder: (context, snapshot) {
        return builder(snapshot.data ?? texts);
      },
    );
  }
}
