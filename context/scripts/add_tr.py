#!/usr/bin/env python3
"""
add_tr.py — Auto-wrap hardcoded strings with tr() for translation in Dart files.

Usage:
    python add_tr.py                          # Dry-run on lib/ui/screens/
    python add_tr.py --apply                  # Apply changes
    python add_tr.py --apply --files a.dart,b.dart   # Specific files only
    python add_tr.py --dir lib/ui/components  # Custom directory
"""

import re
import os
import sys
import shutil
import argparse
from pathlib import Path

# ════════════════════════════════════════════════════════════
# CONFIGURATION
# ════════════════════════════════════════════════════════════

# Base project path — auto-detected relative to this script
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent / "app"  # context/scripts/ -> Detooz/app
DEFAULT_SCAN_DIR = "lib/ui/screens"

TR_IMPORT = "import '../components/tr.dart';"
TR_IMPORT_FROM_SCREENS = "../components/tr.dart"

# ════════════════════════════════════════════════════════════
# EXCLUSION PATTERNS — strings that should NOT be wrapped
# ════════════════════════════════════════════════════════════

# Exact parameter names whose values are NOT user-facing
NON_TEXT_PARAMS = {
    'fontFamily', 'fontWeight', 'ref', 'type', 'mediaType',
    'source', 'route', 'path', 'url', 'key', 'tag', 'id',
    'name',  # widget name param, not display name
    'semanticsLabel', 'restorationId', 'heroTag',
    'debugLabel', 'initialRoute', 'fieldKey',
}

# Regex patterns for strings to SKIP
SKIP_PATTERNS = [
    r"^import\s",                    # import lines
    r"^\s*//",                       # comment lines
    r"^\s*///",                      # doc comment lines
    r"^\s*\*",                       # block comment lines
    r"tr\(",                         # already wrapped with tr()
    r"Tr\(",                         # already using Tr widget
    r"tr\s*\(",                      # tr with space
]

# String content patterns to SKIP
SKIP_STRING_CONTENT = [
    r"^assets/",                     # asset paths
    r"^package:",                    # package URIs
    r"^lib/",                        # file paths
    r"^https?://",                   # URLs
    r"^/",                           # route paths starting with /
    r"^\.",                          # file extensions
    r"^#[0-9A-Fa-f]",               # hex colors
    r"^0x[0-9A-Fa-f]",              # hex values
    r"^\d+\.?\d*$",                  # pure numbers
    r"^[a-z][a-zA-Z]+\.[a-z]",      # dot-notation identifiers
    r"^(true|false|null)$",          # literals
    r"^\w+_\w+$",                    # snake_case identifiers
    r"^[A-Z_]+$",                    # CONSTANT_NAMES (but allow if > 1 word)
    r"^\s*$",                        # empty/whitespace
    r"^IntegralCF$",                 # known font
    r"^Inter$",                      # known font
    r"^Roboto$",                     # known font
    r"^GoogleSans$",                 # known font
    r"^[A-Za-z]$",                   # single char
    r"^all$",                        # filter values
    r"^video$",                      # media types
    r"^image$",                      # media types
    r"^\.dart",                      # dart file refs
]

# ════════════════════════════════════════════════════════════
# DETECTION ENGINE
# ════════════════════════════════════════════════════════════

# Patterns that indicate a string is user-facing text
# Format: (regex_pattern, group_index_for_prefix, group_index_for_string, replacement_template)
WRAP_PATTERNS = [
    # Text('string') → Text(tr('string'))
    (r"""(Text\s*\(\s*)(')((?:[^'\\]|\\.)+?)('(?:\s*,|\s*\)))""", 1, 3),
    (r'''(Text\s*\(\s*)(\")((?:[^\"\\]|\\.)+?)(\"(?:\s*,|\s*\)))''', 1, 3),

    # Named params: label: 'string' → label: tr('string')
    (r"""((?:label|hintText|labelText|helperText|errorText|tooltip|title|message|text|content|subtitle|description|placeholder|hint|counterText|prefixText|suffixText|toolbarTitle)\s*:\s*)(')((?:[^'\\]|\\.)+?)(')""", 1, 3),
    (r'''((?:label|hintText|labelText|helperText|errorText|tooltip|title|message|text|content|subtitle|description|placeholder|hint|counterText|prefixText|suffixText|toolbarTitle)\s*:\s*)(\")((?:[^\"\\]|\\.)+?)(\")''', 1, 3),

    # Function calls with string args: buildSectionLabel(context, 'string')
    (r"""(buildSectionLabel\s*\(\s*\w+\s*,\s*)(')((?:[^'\\]|\\.)+?)(')""", 1, 3),
    (r"""(buildBrutalistHeader\s*\(\s*\w+\s*,\s*)(')((?:[^'\\]|\\.)+?)(')""", 1, 3),

    # _buildTab('string', ...) 
    (r"""(_buildTab\s*\(\s*)(')((?:[^'\\]|\\.)+?)('\s*,)""", 1, 3),

    # NeoSnackBar.show message  
    (r"""(message\s*:\s*)(')((?:[^'\\]|\\.)+?)(')""", 1, 3),

    # Tab/button text in child: Text(...)
    (r"""(child:\s*Text\s*\(\s*)(')((?:[^'\\]|\\.)+?)(')""", 1, 3),
]


def should_skip_line(line: str) -> bool:
    """Check if the entire line should be skipped."""
    stripped = line.strip()
    if not stripped:
        return True
    for pattern in SKIP_PATTERNS:
        if re.search(pattern, stripped):
            return True
    return False


def should_skip_string(s: str) -> bool:
    """Check if a specific string value should NOT be wrapped."""
    s = s.strip()
    if len(s) <= 1:
        return True
    for pattern in SKIP_STRING_CONTENT:
        if re.search(pattern, s):
            return True
    return False


def has_interpolation(s: str) -> bool:
    """Check if string contains Dart interpolation ($var or ${expr})."""
    return '$' in s


def is_in_non_text_param(line: str, match_start: int) -> bool:
    """Check if the match is inside a non-text parameter assignment."""
    prefix = line[:match_start].rstrip()
    for param in NON_TEXT_PARAMS:
        if prefix.endswith(f'{param}:') or prefix.endswith(f'{param} :'):
            return True
    return False


def already_wrapped(line: str, match_start: int) -> bool:
    """Check if the string is already inside a tr() call."""
    prefix = line[:match_start].rstrip()
    if prefix.endswith('tr(') or prefix.endswith('tr ('):
        return True
    # Check for tr(' pattern right before quote
    check = line[max(0, match_start - 4):match_start]
    if 'tr(' in check:
        return True
    return False


class TranslationResult:
    def __init__(self):
        self.wrapped = []       # (file, line_num, before, after)
        self.skipped = []       # (file, line_num, reason, content)
        self.manual_review = [] # (file, line_num, reason, content)
        self.files_modified = set()


def process_line(line: str, line_num: int, filepath: str, result: TranslationResult) -> str:
    """Process a single line and return the modified version."""
    if should_skip_line(line):
        return line

    modified = line

    for pattern, prefix_group, string_group in WRAP_PATTERNS:
        # Find all matches in the current state of the line
        matches = list(re.finditer(pattern, modified))
        if not matches:
            continue

        # Process matches in reverse order to preserve positions
        for match in reversed(matches):
            full_match = match.group(0)
            prefix = match.group(prefix_group)
            string_val = match.group(string_group)
            quote_char = match.group(prefix_group + 1)
            suffix = match.group(prefix_group + 3) if (prefix_group + 3) <= len(match.groups()) else quote_char

            # Skip checks
            if should_skip_string(string_val):
                result.skipped.append((filepath, line_num, "excluded content", string_val))
                continue

            if already_wrapped(modified, match.start()):
                result.skipped.append((filepath, line_num, "already wrapped", string_val))
                continue

            if is_in_non_text_param(modified, match.start()):
                result.skipped.append((filepath, line_num, "non-text param", string_val))
                continue

            if has_interpolation(string_val):
                result.manual_review.append((filepath, line_num, "interpolation", string_val))
                continue

            # Apply the wrap
            old_segment = f"{quote_char}{string_val}{suffix.rstrip(',').rstrip(')')}"
            new_segment = f"tr({quote_char}{string_val}{quote_char})"

            # Build replacement
            new_match = f"{prefix}tr({quote_char}{string_val}{quote_char}){suffix[len(quote_char):]}"
            
            start, end = match.start(), match.end()
            modified = modified[:start] + new_match + modified[end:]

            result.wrapped.append((filepath, line_num, line.rstrip(), modified.rstrip()))
            result.files_modified.add(filepath)

    return modified


def ensure_tr_import(lines: list, filepath: str) -> list:
    """Add tr.dart import if not present."""
    has_import = any(TR_IMPORT_FROM_SCREENS in line for line in lines)
    if has_import:
        return lines

    # Find the last import line and insert after it
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i

    if last_import_idx >= 0:
        lines.insert(last_import_idx + 1, TR_IMPORT + '\n')
    else:
        lines.insert(0, TR_IMPORT + '\n')

    return lines


def process_file(filepath: str, result: TranslationResult, apply: bool) -> None:
    """Process a single Dart file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    changed = False

    for i, line in enumerate(lines):
        new_line = process_line(line, i + 1, filepath, result)
        new_lines.append(new_line)
        if new_line != line:
            changed = True

    if changed and apply:
        # Ensure import exists
        new_lines = ensure_tr_import(new_lines, filepath)

        # Create backup
        backup_path = filepath + '.bak'
        shutil.copy2(filepath, backup_path)

        # Write modified file
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)


def print_report(result: TranslationResult, apply: bool):
    """Print a formatted report."""
    mode = "APPLIED" if apply else "DRY RUN"
    print(f"\n{'═' * 55}")
    print(f"  Translation Wrapper — {mode}")
    print(f"{'═' * 55}\n")

    if result.wrapped:
        # Group by file
        from collections import defaultdict
        by_file = defaultdict(list)
        for filepath, line_num, before, after in result.wrapped:
            fname = os.path.basename(filepath)
            by_file[fname].append((line_num, before.strip(), after.strip()))

        for fname, changes in sorted(by_file.items()):
            print(f"📄 {fname}")
            for line_num, before, after in changes:
                # Show a condensed diff
                print(f"  L{line_num}:")
                print(f"    - {before[:90]}")
                print(f"    + {after[:90]}")
            print()

    if result.manual_review:
        print(f"⚠️  MANUAL REVIEW NEEDED ({len(result.manual_review)} items):")
        for filepath, line_num, reason, content in result.manual_review:
            fname = os.path.basename(filepath)
            print(f"  {fname}:L{line_num} — {reason}: '{content[:60]}'")
        print()

    print(f"{'─' * 55}")
    print(f"📊 Summary:")
    print(f"   ✅ Wrapped:       {len(result.wrapped)}")
    print(f"   ⏭️  Skipped:       {len(result.skipped)}")
    print(f"   ⚠️  Manual review: {len(result.manual_review)}")
    print(f"   📁 Files changed: {len(result.files_modified)}")
    if not apply and result.wrapped:
        print(f"\n   Run with --apply to commit changes.")
    print(f"{'═' * 55}\n")


def main():
    parser = argparse.ArgumentParser(description="Auto-wrap Dart strings with tr() for translation")
    parser.add_argument('--apply', action='store_true', help='Apply changes (default: dry-run)')
    parser.add_argument('--dir', default=DEFAULT_SCAN_DIR, help=f'Directory to scan (default: {DEFAULT_SCAN_DIR})')
    parser.add_argument('--files', default='', help='Comma-separated list of specific filenames to process')
    parser.add_argument('--project', default=str(PROJECT_ROOT), help='Project root path')
    args = parser.parse_args()

    project_root = Path(args.project)
    scan_dir = project_root / args.dir

    if not scan_dir.exists():
        print(f"❌ Directory not found: {scan_dir}")
        sys.exit(1)

    # Collect target files
    if args.files:
        target_files = []
        for fname in args.files.split(','):
            fname = fname.strip()
            fpath = scan_dir / fname
            if fpath.exists():
                target_files.append(str(fpath))
            else:
                print(f"⚠️  File not found: {fpath}")
    else:
        target_files = sorted(str(p) for p in scan_dir.glob('*.dart'))

    if not target_files:
        print("❌ No Dart files found to process.")
        sys.exit(1)

    print(f"\n🔍 Scanning {len(target_files)} files in {scan_dir}")
    if not args.apply:
        print("   Mode: DRY RUN (no files will be modified)\n")

    result = TranslationResult()

    for filepath in target_files:
        process_file(filepath, result, args.apply)

    print_report(result, args.apply)


if __name__ == '__main__':
    main()
