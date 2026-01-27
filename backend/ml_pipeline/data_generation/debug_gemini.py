
import os
import google.generativeai as genai
from dotenv import load_dotenv

# Load .env manually to be sure
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ENV_PATH = os.path.join(BASE_DIR, ".env")
load_dotenv(ENV_PATH)

api_key = os.getenv("GOOG_API_KEY")
print(f"Key loaded: {api_key[:5]}...{api_key[-5:] if api_key else 'None'}")

if not api_key:
    exit("No Key")

genai.configure(api_key=api_key)

print("Listing Models:")
try:
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            print(f"- {m.name}")
except Exception as e:
    print(f"Error: {e}")
