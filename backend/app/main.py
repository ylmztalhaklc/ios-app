# ===================================================================
# HEALTHCARE API - ANA UYGULAMA DOSYASI (main.py)
# ===================================================================
# Bu dosya FastAPI uygulamasının ana giriş noktasıdır.
# Tüm router'ları birleştirir ve CORS ayarlarını yapılandırır.
# ===================================================================

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from .database import Base, engine
from . import models
from .routers import auth, tasks, notifications, users, messages, statistics, uploads

# Veritabanı tablolarını otomatik oluştur
# Uygulama ilk çalıştığında models.py'deki tüm modeller için tablolar yaratılır
Base.metadata.create_all(bind=engine)

# FastAPI uygulaması oluştur
app = FastAPI(title="HealthCare API (New)")

# CORS Middleware ekle - Frontend'in API'ye erişebilmesi için gerekli
# Development ortamı için tüm originlere izin verilmiş (*)
# Production'da mutlaka spesifik origin adresleri belirtilmelidir
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tüm kaynaklara izin ver (dev için)
    allow_credentials=True,  # Cookie ve credential'lara izin ver
    allow_methods=["*"],  # Tüm HTTP metodlarına izin ver (GET, POST, PUT, DELETE, vb.)
    allow_headers=["*"],  # Tüm header'lara izin ver
)

# Uploads klasörü için statik dosya sunucu
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Root endpoint - API'nin çalıştığını kontrol etmek için
@app.get("/")
def read_root():
    """Ana sayfa endpoint'i - API'nin aktif olduğunu gösterir"""
    return {"message": "HealthCare API is running"}

# Router'ları uygulamaya ekle - Her router farklı bir modülü yönetir
app.include_router(auth.router)  # Kimlik doğrulama: kayıt ve giriş
app.include_router(tasks.router)  # Görev yönetimi: şablon ve görev işlemleri
app.include_router(notifications.router)  # Bildirim yönetimi
app.include_router(users.router)  # Kullanıcı bilgileri
app.include_router(messages.router)  # Mesajlaşma
app.include_router(statistics.router)  # İstatistikler
app.include_router(uploads.router)  # Dosya yükleme
