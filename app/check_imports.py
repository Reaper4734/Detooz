import os
from pathlib import Path

def check_imports():
    path = Path('lib/ui')
    missing_imports = []
    
    print("Checking for missing Tr imports...")
    
    for file_path in path.rglob('*.dart'):
        if file_path.name == 'tr.dart':
            continue
            
        try:
            content = file_path.read_text(encoding='utf-8')
        except:
            continue
            
        if 'Tr(' in content:
            has_import = 'tr.dart' in content
            if not has_import:
                print(f"❌ Missing import in: {file_path}")
                missing_imports.append(file_path)
                
                # Attempt to fix
                lines = content.split('\n')
                last_import = -1
                for i, line in enumerate(lines):
                    if line.strip().startswith('import '):
                        last_import = i
                
                if last_import != -1:
                    # Determine path
                    parts = file_path.parts
                    if 'screens' in parts:
                        imp = "import '../components/tr.dart';"
                        if 'admin' in parts: # deeper
                             imp = "import '../../components/tr.dart';"
                    elif 'components' in parts:
                        imp = "import 'tr.dart';"
                    else:
                        imp = "import 'components/tr.dart';" # Guess
                        
                    # Better logic: relative path
                    # But for now, let's just use strict paths based on known structure
                    # App structure: lib/ui/screens/..., lib/ui/components/...
                    
                    if 'lib\\ui\\screens' in str(file_path) or 'lib/ui/screens' in str(file_path):
                        if 'admin' in str(file_path):
                             imp = "import '../../components/tr.dart';"
                        else:
                             imp = "import '../components/tr.dart';"
                    
                    lines.insert(last_import + 1, imp)
                    file_path.write_text('\n'.join(lines), encoding='utf-8')
                    print("   ✅ Fixed automatically")
    
    if not missing_imports:
        print("✅ All files seem to have imports.")

if __name__ == '__main__':
    check_imports()
