import markdown
# from xhtml2pdf import pisa
import os

# Paths
ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\f464b77a-859d-479a-abd5-7430c34b1d86"
MD_FILE = os.path.join(ARTIFACT_DIR, "model_evaluation_report.md")
PDF_FILE = os.path.join(ARTIFACT_DIR, "model_evaluation_report.pdf")

def convert_md_to_pdf():
    print(f"Reading {MD_FILE}...")
    with open(MD_FILE, "r", encoding="utf-8") as f:
        text = f.read()

    # Convert MD to HTML
    html_content = markdown.markdown(text, extensions=['tables'])
    
    # Add some basic styling
    full_html = f"""
    <html>
    <head>
    <style>
        body {{ font-family: sans-serif; font-size: 12px; }}
        table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        h1 {{ color: #333; }}
        h2 {{ color: #555; border-bottom: 1px solid #ccc; padding-bottom: 5px; }}
    </style>
    </head>
    <body>
    {html_content}
    </body>
    </html>
    """
    
    HTML_FILE = os.path.join(ARTIFACT_DIR, "model_evaluation_report.html")
    print(f"Generating HTML at {HTML_FILE}...")
    with open(HTML_FILE, "w", encoding="utf-8") as html_file:
        html_file.write(full_html)
    print("✅ HTML generated successfully!")

if __name__ == "__main__":
    convert_md_to_pdf()
