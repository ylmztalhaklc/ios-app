# ===================================================================
# PYDANTIC ŞEMALARI (schemas.py)
# ===================================================================
# API request ve response için veri doğrulama şemaları.
# Pydantic, gelen ve giden verilerin formatını doğrular.
# ===================================================================

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr


# ===================================================================
# KULLANICI ŞEMALARI
# ===================================================================

class UserBase(BaseModel):
    """
    Kullanıcı için temel alanlar.
    Diğer kullanıcı şemaları bundan türer.
    """
    full_name: str  # Kullanıcının tam adı
    email: EmailStr  # Email adresi (Pydantic otomatik doğrular)
    role: str  # Rol: "hasta_yakini" veya "hasta_bakici"


class UserCreate(UserBase):
    """
    Yeni kullanıcı kaydı için kullanılır.
    UserBase'e ek olarak şifre alanı içerir.
    """
    password: str  # Düz metin şifre (veritabanında hashlenecek)


class UserRead(UserBase):
    """
    API'den kullanıcı bilgisi dönerken kullanılır.
    Şifre bilgisi döndürülmez (güvenlik).
    """
    id: int  # Kullanıcı ID'si
    is_active: bool  # Hesap aktif mi?

    class Config:
        from_attributes = True  # SQLAlchemy modellerinden otomatik dönüşüm


# ===================================================================
# GÖREV ŞABLONU ŞEMALARI
# ===================================================================

class TaskTemplateBase(BaseModel):
    """
    Görev şablonu için temel alanlar.
    Tekrar eden görevler için şablon tanımı.
    """
    title: str  # Görev başlığı (örn: "Kahvaltı hazırla")
    description: Optional[str] = None  # Görev açıklaması ve talimatlar (opsiyonel)
    default_time: Optional[str] = None  # Varsayılan saat - "HH:MM" formatında (örn: "09:00")


class TaskTemplateCreate(TaskTemplateBase):
    """
    Yeni görev şablonu oluşturmak için kullanılır.
    Sadece hasta_yakini oluşturabilir.
    """
    created_by_id: int  # Şablonu oluşturan kullanıcı ID'si (hasta_yakini)


class TaskTemplateRead(TaskTemplateBase):
    """
    API'den görev şablonu bilgisi dönerken kullanılır.
    Tüm şablon detaylarını içerir.
    """
    id: int  # Şablon ID'si
    created_by_id: int  # Oluşturan kullanıcı ID'si
    is_active: bool  # Şablon aktif mi?
    created_at: datetime  # Oluşturulma tarihi

    class Config:
        from_attributes = True


# ---------- Task Instance (atanmış görev) ----------

class TaskInstanceCreate(BaseModel):
    template_id: int
    title: Optional[str] = None
    description: Optional[str] = None
    created_by_id: int      # hasta yakını id'si
    assigned_to_id: int     # hasta bakıcı id'si
    scheduled_for: datetime # YYYY-MM-DDTHH:MM:SS (ISO format)


class TaskInstanceRead(BaseModel):
    id: int
    template_id: int
    title: Optional[str] = None
    description: Optional[str] = None
    status: str
    scheduled_for: datetime
    problem_message: Optional[str] = None
    problem_severity: Optional[str] = None
    resolution_note: Optional[str] = None
    completion_photo_url: Optional[str] = None
    rating: Optional[int] = None
    review_note: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    created_by_id: int
    assigned_to_id: int

    class Config:
        from_attributes = True


class TaskInstanceUpdate(BaseModel):
    """
    Hasta yakınının görev üzerinde yapacağı güncellemeler:
    - scheduled_for (saat/tarih değişikliği)
    Şimdilik sadece zamanı değiştiriyoruz, istenirse genişletilir.
    """
    scheduled_for: datetime


class TaskStatusUpdate(BaseModel):
    """
    Hasta bakıcının görev durumu güncellemesi için payload.
    """
    task_id: int
    user_id: int               # güncelleme yapan kullanıcı (hasta bakıcı)
    status: str                # "pending" | "in_progress" | "done" | "problem" | "cancelled"
    problem_message: Optional[str] = None  # Sorun mesajı (sadece status="problem" ise doldurulur)
    problem_severity: Optional[str] = None  # mild | moderate | critical
    resolution_note: Optional[str] = None   # Çözüm notu


# ===================================================================
# BİLDİRİM ŞEMALARI
# ===================================================================

class NotificationRead(BaseModel):
    """
    API'den bildirim bilgisi dönerken kullanılır.
    Kullanıcılara gönderilen bildirimleri temsil eder.
    """
    id: int  # Bildirim ID'si
    user_id: int  # Bildirimin sahibi kullanıcı ID'si
    message: str  # Bildirim mesajı
    is_read: bool  # Okundu mu?
    created_at: datetime  # Oluşturulma zamanı

    class Config:
        from_attributes = True


# ===================================================================
# KİMLİK DOĞRULAMA ŞEMALARI
# ===================================================================

class LoginRequest(BaseModel):
    """
    Kullanıcı girişi için request şeması.
    Email ve şifre ile giriş yapılır.
    """
    email: EmailStr  # Kullanıcının email adresi
    password: str  # Kullanıcının şifresi (düz metin)


class LoginResponse(BaseModel):
    """
    Başarılı giriş sonrası dönülen response.
    Kullanıcı bilgilerini içerir.
    """
    user: UserRead  # Giriş yapan kullanıcının bilgileri


# ===================================================================
# MESAJ ŞEMALARI
# ===================================================================

class MessageCreate(BaseModel):
    sender_id: int
    receiver_id: int
    content: Optional[str] = None


class MessageAttachmentRead(BaseModel):
    id: int
    message_id: int
    file_type: str
    file_path: str
    file_name: str
    file_size: Optional[int] = None
    uploaded_at: datetime

    class Config:
        from_attributes = True


class MessageRead(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    content: Optional[str] = None
    sent_at: datetime
    is_edited: bool
    edited_at: Optional[datetime] = None
    is_deleted: bool
    is_read: bool
    attachments: list[MessageAttachmentRead] = []

    class Config:
        from_attributes = True


class ConversationPreview(BaseModel):
    other_user_id: int
    other_user_name: str
    other_user_role: str = ""
    last_message: Optional[str] = None
    last_message_time: Optional[datetime] = None
    unread_count: int = 0
