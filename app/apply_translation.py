import subprocess
import sys
import os

def run_command(command, description):
    print(f"\n🔄 {description}...")
    try:
        # Check if python scripts exist before running
        script_name = command.split()[1] if command.startswith("python") else ""
        if script_name and not os.path.exists(script_name):
            print(f"⚠️ Script not found: {script_name}")
            return False

        subprocess.check_call(command, shell=True)
        print(f"✅ {description} complete.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error during {description}: {e}")
        return False

def main():
    print("="*60)
    print("🌍 Detooz Translation Auto-Integrator")
    print("="*60)
    print("This script will scan your new UI code and automatically")
    print("wire it up to the Translation Service.")
    
    # 1. Convert Text -> Tr
    # We target 'lib/ui' by default to catch all screens/components
    if not run_command("python migrate_to_tr.py lib/ui", "Migrating Text widgets to Tr"):
        sys.exit(1)
    
    # 2. Fix Imports
    if not run_command("python check_imports.py", "Ensuring correct imports"):
        sys.exit(1)
    
    # 3. Clean up Consts
    # Tr is a FutureBuilder, so it cannot be const. We must remove parent consts.
    if not run_command("python cleanup_const.py", "Removing invalid 'const' keywords"):
        sys.exit(1)
    
    print("\n" + "="*60)
    print("✨ SUCCESS! New UI components are now translation-ready.")
    print("   Run 'flutter run' to test.")
    print("="*60)

if __name__ == "__main__":
    main()
