import os
import re
from pathlib import Path

def remove_const_if_tr_present(file_path):
    try:
        content = file_path.read_text(encoding='utf-8')
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return 0

    if 'Tr(' not in content:
        return 0

    original_content = content
    
    # Replace "children: const [" -> "children: ["
    content = re.sub(r'children:\s*const\s*\[', 'children: [', content)
    
    # Replace "const <Widget>[" -> "<Widget>["
    content = re.sub(r'const\s+<Widget>\s*\[', '<Widget>[', content)
    
    # Replace specific const widgets that might wrap Tr
    widgets_to_unconst = ['Row', 'Column', 'Center', 'Padding', 'Container', 'SizedBox', 'Expanded', 'Flexible', 'Wrap', 'Stack', 'EdgeInsets']
    for w in widgets_to_unconst:
        content = re.sub(fr'const\s+{w}\(', f'{w}(', content)
            
    if content != original_content:
        file_path.write_text(content, encoding='utf-8')
        return 1
    return 0

def main():
    path = Path('lib/ui')
    count = 0
    for file_path in path.rglob('*.dart'):
        if remove_const_if_tr_present(file_path):
            print(f"Fixed consts in: {file_path}")
            count += 1
    print(f"Processed {count} files.")

if __name__ == '__main__':
    main()
