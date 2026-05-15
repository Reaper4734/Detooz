import os
import collections

exclude_dirs = {'.git', 'node_modules', 'build', '.dart_tool', 'venv', '__pycache__', 'Pods', '.idea', 'android/.gradle'}
code_exts = {'.dart', '.py', '.json', '.yaml', '.yml', '.md', '.html', '.js', '.xml', '.gradle', '.ps1'}

ext_counts = collections.defaultdict(int)
cat_counts = collections.defaultdict(int)
total = 0

for root, dirs, files in os.walk(os.getcwd()):
    dirs[:] = [d for d in dirs if d not in exclude_dirs]
    for file in files:
        ext = os.path.splitext(file)[1].lower()
        if ext in code_exts:
            fp = os.path.join(root, file)
            filepath = fp.lower()
            
            # Determine Component Category
            if 'app\\lib' in filepath or 'app/lib' in filepath:
                category = 'App (Flutter Code)'
            elif 'backend\\app' in filepath or 'backend/app' in filepath:
                category = 'Backend (Python FastAPI)'
            elif 'android' in filepath or 'ios' in filepath:
                category = 'App (Native Configs)'
            else:
                category = 'Infrastructure & Scripts'

            lines = 0
            try:
                with open(fp, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = sum(1 for _ in f)
            except:
                pass
            
            ext_counts[ext] += lines
            cat_counts[category] += lines
            total += lines

print("\n=== TOTAL LINES OF CODE ===")
print("{:,}".format(total))

print("\n=== BY CATEGORY ===")
for cat, cnt in sorted(cat_counts.items(), key=lambda x: -x[1]):
    print(f"- {cat}: {cnt:,} lines")

print("\n=== BY FILE TYPE ===")
for ext, cnt in sorted(ext_counts.items(), key=lambda x: -x[1]):
    print(f"- {ext}: {cnt:,} lines")
