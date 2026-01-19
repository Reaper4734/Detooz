import sqlite3

def list_guardians_sync():
    print("Connecting to detooz.db...")
    try:
        conn = sqlite3.connect('detooz.db')
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, name, phone, telegram_chat_id FROM guardians")
        rows = cursor.fetchall()
        
        print(f"\nFound {len(rows)} guardians:")
        for row in rows:
            print(f"ID: {row[0]}, Name: {row[1]}, Phone: {row[2]}, Telegram Chat ID: {row[3]}")
            
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    list_guardians_sync()
