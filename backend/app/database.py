# ===================================================================
# VERİTABANI YAPLANDIRMA DOSYASI (database.py)
# ===================================================================
# SQLAlchemy kullanarak veritabanı bağlantısını yapılandırır.
# SQLite veritabanı kullanılmaktadır.
# ===================================================================

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# SQLite veritabanı bağlantı URL'i
# ./healthcare.db dosyası projenin kök dizininde oluşturulur
SQLALCHEMY_DATABASE_URL = "sqlite:///./healthcare.db"

# SQLAlchemy engine oluştur
# check_same_thread=False: SQLite'ın thread güvenliği kontrolünü devre dışı bırak
# FastAPI async çalıştığı için bu ayar gereklidir
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# SessionLocal: Her veritabanı işlemi için yeni bir session oluşturur
# autocommit=False: Manuel commit yapmak gerekir (güvenlik için)
# autoflush=False: Otomatik flush işlemini devre dışı bırak
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base: Tüm model sınıflarının türeyeceği temel sınıf
Base = declarative_base()


def get_db():
    """
    Veritabanı session'ı dependency injection için.
    FastAPI endpoint'lerinde Depends(get_db) ile kullanılır.
    Her request için yeni bir session oluşturur ve işlem bitince kapatır.
    
    Kullanım örneği:
    @app.get("/users")
    def get_users(db: Session = Depends(get_db)):
        return db.query(User).all()
    """
    from fastapi import Depends, HTTPException, status
    db = SessionLocal()  # Yeni session oluştur
    try:
        yield db  # Session'ı endpoint'e ver
    finally:
        db.close()  # İşlem bitince session'ı kapat
