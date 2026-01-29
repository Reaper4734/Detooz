#!/usr/bin/env python3
"""
Text to Tr Migration Script
Converts Text('string') to Tr('string') for translation support.
Only converts static strings, not dynamic content.

Usage: python migrate_to_tr.py [--dry-run] [path]
"""

import os
import re
import sys
import io
from pathlib import Path

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Files/patterns to skip
SKIP_FILES = {
    'tr.dart',  # The Tr widget itself
    'language_selector_screen.dart',  # Already uses Tr
    'language_config.dart',
}

SKIP_DIRS = {
    '.dart_tool',
    'build',
    '.git',
    'test',
    'integration_test',
}

# Import line to add
TR_IMPORT = "import '../components/tr.dart';"
TR_IMPORT_SERVICES = "import '../../ui/components/tr.dart';"

def find_dart_files(root_path: str) -> list[Path]:
    """Find all Dart files in the given path."""
    files = []
    for path in Path(root_path).rglob('*.dart'):
        # Skip unwanted directories
        if any(skip in path.parts for skip in SKIP_DIRS):
            continue
        # Skip specific files
        if path.name in SKIP_FILES:
            continue
        files.append(path)
    return files

def should_convert(text_content: str) -> bool:
    """Check if this Text content should be converted."""
    # Skip empty strings
    if not text_content.strip():
        return False
        
    # We NOW allow variables/expressions (dynamic content)
    # The user explicitly asked for this.
    
    # Still skip if it looks like just an empty string literal
    if text_content.strip() in ["''", '""']:
        return False
        
    return True

def convert_text_to_tr(content: str) -> tuple[str, int, list[str]]:
    """
    Convert Text widgets to Tr widgets.
    Returns: (new_content, count_of_changes, list_of_changes)
    """
    changes = []
    count = 0
    
    # Pattern to match Text('string') or Text("string")
    # Handles: Text('string'), Text('string', style: ...), const Text('string')
    pattern = r'\b(const\s+)?Text\s*\(\s*([\'"][^\'"]*[\'"])'
    
    def replacer(match):
        nonlocal count
        const_prefix = match.group(1) or ''
        string_content = match.group(2)
        
        if should_convert(string_content):
            count += 1
            # Remove const for Tr (it uses FutureBuilder internally)
            changes.append(f"Text({string_content}) → Tr({string_content})")
            return f'Tr({string_content}'
        return match.group(0)
    
    new_content = re.sub(pattern, replacer, content)
    return new_content, count, changes


def convert_labels_to_tr(content: str) -> tuple[str, int, list[str]]:
    """
    Convert String parameters (label:, text:, hintText:, etc.) to use tr() function.
    This handles patterns like:
      label: 'Home'  →  label: tr('Home')
      hintText: 'Enter name'  →  hintText: tr('Enter name')
    Returns: (new_content, count_of_changes, list_of_changes)
    """
    changes = []
    count = 0
    
    # String parameters that should be translated
    # Includes: input fields, chips, tabs, buttons, dialogs, tooltips
    params = [
        # Input decorations
        'label', 'hintText', 'labelText', 'helperText', 'counterText', 
        'prefixText', 'suffixText', 'errorText',
        # Accessibility
        'semanticLabel', 'tooltip', 
        # Dialogs & Alerts
        'message', 'title', 'confirmText', 'cancelText', 
        # Buttons & Tabs & Chips
        'text', 'buttonText', 'actionText', 
        # Snackbar & other
        'content',
    ]
    
    for param in params:
        # Pattern: param: 'string' or param: "string" (not already using tr())
        pattern = rf"({param}:\s*)(['\"])([^'\"]+)\2(?!\s*\))"  # Negative lookahead to avoid already wrapped
        
        def make_replacer(param_name):
            def replacer(match):
                nonlocal count
                prefix = match.group(1)  # "label: "
                quote = match.group(2)    # ' or "
                string_val = match.group(3)  # the string content
                
                # Skip if already looks like tr() call
                if "tr(" in prefix:
                    return match.group(0)
                    
                count += 1
                changes.append(f"{param_name}: {quote}{string_val}{quote} → {param_name}: tr({quote}{string_val}{quote})")
                return f"{prefix}tr({quote}{string_val}{quote})"
            return replacer
        
        content = re.sub(pattern, make_replacer(param), content)
    
    return content, count, changes

def add_tr_import(content: str, file_path: Path) -> str:
    """Add Tr import if not already present."""
    if "import" not in content:
        return content
    if "components/tr.dart" in content:
        return content  # Already imported
    
    # Check if either Tr() widget or tr() function is used
    uses_tr = "Tr(" in content or ": tr(" in content or "= tr(" in content
    if not uses_tr:
        return content  # No Tr/tr usage, no need to import
    
    # Determine import path based on file location
    parts = file_path.parts
    if 'screens' in parts:
        import_line = "import '../components/tr.dart';\n"
    elif 'components' in parts:
        import_line = "import 'tr.dart';\n"
    else:
        # For other locations, use relative path
        import_line = "import '../ui/components/tr.dart';\n"
    
    # Find the last import line and add after it
    lines = content.split('\n')
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i
    
    if last_import_idx >= 0:
        lines.insert(last_import_idx + 1, import_line.strip())
        return '\n'.join(lines)
    
    return content

def process_file(file_path: Path, dry_run: bool = True) -> tuple[int, list[str]]:
    """Process a single Dart file."""
    try:
        content = file_path.read_text(encoding='utf-8')
    except Exception as e:
        print(f"  ⚠️ Error reading {file_path}: {e}")
        return 0, []
    
    total_count = 0
    all_changes = []
    
    # 1. Convert Text() to Tr()
    new_content, count1, changes1 = convert_text_to_tr(content)
    total_count += count1
    all_changes.extend(changes1)
    
    # 2. Convert label: 'string' to label: tr('string')
    new_content, count2, changes2 = convert_labels_to_tr(new_content)
    total_count += count2
    all_changes.extend(changes2)
    
    if total_count > 0:
        # Add tr.dart import if needed (covers both Tr and tr())
        new_content = add_tr_import(new_content, file_path)
        
        if not dry_run:
            file_path.write_text(new_content, encoding='utf-8')
        
        return total_count, all_changes
    
    return 0, []

def main():
    dry_run = '--dry-run' in sys.argv
    
    # Get path from args or use default
    path = None
    for arg in sys.argv[1:]:
        if not arg.startswith('--'):
            path = arg
            break
    
    if path is None:
        path = 'lib/ui/screens'  # Default to screens folder
    
    print("=" * 60)
    print("🔄 Text → Tr Migration Script")
    print("=" * 60)
    print(f"📁 Path: {path}")
    print(f"🔍 Mode: {'DRY RUN (no changes)' if dry_run else 'LIVE (will modify files)'}")
    print()
    
    if not Path(path).exists():
        print(f"❌ Path not found: {path}")
        return 1
    
    files = find_dart_files(path)
    print(f"📋 Found {len(files)} Dart files to process\n")
    
    total_changes = 0
    files_changed = 0
    
    for file_path in sorted(files):
        count, changes = process_file(file_path, dry_run)
        if count > 0:
            files_changed += 1
            total_changes += count
            rel_path = file_path.relative_to(Path(path).parent) if Path(path).is_dir() else file_path.name
            print(f"📝 {rel_path}: {count} changes")
            for change in changes[:5]:  # Show first 5 changes
                print(f"   └─ {change}")
            if len(changes) > 5:
                print(f"   └─ ... and {len(changes) - 5} more")
            print()
    
    print("=" * 60)
    print(f"📊 Summary:")
    print(f"   Files modified: {files_changed}")
    print(f"   Total changes:  {total_changes}")
    print("=" * 60)
    
    if dry_run and total_changes > 0:
        print("\n💡 Run without --dry-run to apply changes:")
        print(f"   python migrate_to_tr.py {path}")
    
    return 0

if __name__ == '__main__':
    main()
