import sqlite3

conn = sqlite3.connect('detooz.db')
cursor = conn.cursor()

with open('db_output.txt', 'w') as f:
    # Check all tables
    f.write("=== ALL TABLES ===\n")
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = cursor.fetchall()
    for t in tables:
        f.write(f"{t[0]}\n")
    
    f.write("\n=== GUARDIAN_LINKS TABLE ===\n")
    cursor.execute('SELECT * FROM guardian_links')
    cols = [desc[0] for desc in cursor.description]
    f.write(f"{cols}\n")
    for row in cursor.fetchall():
        f.write(f"{row}\n")
    
    # Check if there's a legacy "guardians" table
    f.write("\n=== GUARDIANS TABLE (Legacy) ===\n")
    try:
        cursor.execute('SELECT * FROM guardians')
        cols = [desc[0] for desc in cursor.description]
        f.write(f"{cols}\n")
        for row in cursor.fetchall():
            f.write(f"{row}\n")
    except:
        f.write("Table does not exist\n")
    
    f.write("\n=== GUARDIAN_ACCOUNTS TABLE ===\n")
    cursor.execute('SELECT * FROM guardian_accounts')
    cols = [desc[0] for desc in cursor.description]
    f.write(f"{cols}\n")
    for row in cursor.fetchall():
        f.write(f"{row}\n")

conn.close()
print("Output written to db_output.txt")
