import sqlite3

conn = sqlite3.connect('healthcare.db')
cursor = conn.cursor()

# Mevcut tabloları kontrol et
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = cursor.fetchall()
print("Mevcut tablolar:", [t[0] for t in tables])

# task_instance tablosuna yeni sütunlar ekle
new_columns = [
    ("title", "TEXT"),
    ("description", "TEXT"),
    ("problem_severity", "TEXT"),
    ("resolution_note", "TEXT"),
    ("completion_photo_url", "TEXT"),
    ("rating", "INTEGER"),
    ("review_note", "TEXT"),
]

# Mevcut sütunları kontrol et
cursor.execute("PRAGMA table_info(task_instance)")
existing_columns = [col[1] for col in cursor.fetchall()]
print("task_instance mevcut sütunlar:", existing_columns)

for col_name, col_type in new_columns:
    if col_name not in existing_columns:
        try:
            cursor.execute(f"ALTER TABLE task_instance ADD COLUMN {col_name} {col_type}")
            print(f"Eklendi: {col_name}")
        except Exception as e:
            print(f"Hata ({col_name}): {e}")
    else:
        print(f"Zaten var: {col_name}")

# Message tablosu oluştur
cursor.execute("""
CREATE TABLE IF NOT EXISTS message (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_id INTEGER NOT NULL,
    receiver_id INTEGER NOT NULL,
    content TEXT,
    sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_edited BOOLEAN DEFAULT 0,
    edited_at DATETIME,
    is_deleted BOOLEAN DEFAULT 0,
    is_read BOOLEAN DEFAULT 0,
    FOREIGN KEY (sender_id) REFERENCES app_user(id),
    FOREIGN KEY (receiver_id) REFERENCES app_user(id)
)
""")
print("Message tablosu oluşturuldu/kontrol edildi")

# MessageAttachment tablosu oluştur
cursor.execute("""
CREATE TABLE IF NOT EXISTS message_attachment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id INTEGER NOT NULL,
    file_type TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES message(id)
)
""")
print("MessageAttachment tablosu oluşturuldu/kontrol edildi")

conn.commit()
conn.close()
print("\nVeritabanı güncellendi!")
