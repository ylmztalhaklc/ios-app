# ===================================================================
# VERİTABANI MODELLERİ (models.py)
# ===================================================================
# SQLAlchemy ORM kullanarak veritabanı tablolarını tanımlar.
# Her sınıf bir veritabanı tablosunu temsil eder.
# ===================================================================

from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship

from .database import Base


# ===================================================================
# KULLANICI MODELİ (AppUser)
# ===================================================================
class AppUser(Base):
    """
    Sistem kullanıcılarını temsil eder.
    İki tip kullanıcı vardır:
    1. hasta_yakini: Görev oluşturan, bakıcılara görev atayan kullanıcı
    2. hasta_bakici: Görevleri yerine getiren, durum güncelleyen kullanıcı
    """
    __tablename__ = "app_user"

    # Birincil anahtar - Otomatik artan benzersiz ID
    id = Column(Integer, primary_key=True, index=True)
    
    # Kullanıcının tam adı
    full_name = Column(String, nullable=False)
    
    # Email adresi - Benzersiz olmalı ve giriş için kullanılır
    email = Column(String, unique=True, index=True, nullable=False)
    
    # Kullanıcı rolü: "hasta_yakini" veya "hasta_bakici"
    role = Column(String, nullable=False)
    
    # Hashlenmiş şifre - Düz metin olarak saklanmaz
    hashed_password = Column(String, nullable=False)
    
    # Kullanıcı aktif mi? (Hesap devre dışı bırakma için)
    is_active = Column(Boolean, default=True)

    # İlişkiler (Relationships)
    # Kullanıcının oluşturduğu görev şablonları
    created_task_templates = relationship("TaskTemplate", back_populates="created_by")

    # Kullanıcıya atanan görevler (hasta_bakici için)
    assigned_task_instances = relationship(
        "TaskInstance",
        back_populates="assigned_to",
        foreign_keys="TaskInstance.assigned_to_id"
    )

    # Kullanıcının aldığı bildirimler
    created_notifications = relationship("Notification", back_populates="user")

    # Kullanıcının aktivite kayıtları
    activity_logs = relationship("ActivityLog", back_populates="user")


# ===================================================================
# GÖREV ŞABLONU MODELİ (TaskTemplate)
# ===================================================================
class TaskTemplate(Base):
    """
    Görev şablonlarını saklar.
    Hasta yakını tekrar eden görevler için şablon oluşturur.
    Örnek: "Kahvaltı hazırla", "İlaç ver", "Oda temizliği" gibi.
    Bu şablonlardan TaskInstance'lar oluşturularak bakıcılara atama yapılır.
    """
    __tablename__ = "task_template"

    # Birincil anahtar
    id = Column(Integer, primary_key=True, index=True)
    
    # Görev başlığı (örn: "Kahvaltı hazırla")
    title = Column(String, nullable=False)
    
    # Görev açıklaması - Detaylı talimatlar içerir (opsiyonel)
    description = Column(Text, nullable=True)
    
    # Varsayılan saat - Şablondan görev oluşturulurken kullanılır (HH:MM formatında)
    default_time = Column(String, nullable=True)
    
    # Şablonu oluşturan kullanıcı ID'si (hasta_yakini olmalı)
    created_by_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)
    
    # Şablon aktif mi? (Silinmek yerine pasif yapılabilir)
    is_active = Column(Boolean, default=True)
    
    # Oluşturulma tarihi
    created_at = Column(DateTime, default=datetime.utcnow)

    # İlişkiler
    # Şablonu oluşturan kullanıcı
    created_by = relationship("AppUser", back_populates="created_task_templates")

    # Bu şablondan oluşturulmuş görev örnekleri
    task_instances = relationship("TaskInstance", back_populates="template")


# ===================================================================
# GÖREV ÖRNEĞİ MODELİ (TaskInstance)
# ===================================================================
class TaskInstance(Base):
    """
    Bir görev şablonundan oluşturulmuş, belirli bir tarihe zamanlanmış,
    belirli bir bakıcıya atanmış görevi temsil eder.
    
    Durum çevrimi:
    pending -> in_progress -> done (başarılı)
    pending -> in_progress -> problem (sorun var)
    pending/in_progress -> cancelled (iptal edildi)
    """
    __tablename__ = "task_instance"

    # Birincil anahtar
    id = Column(Integer, primary_key=True, index=True)
    
    # Hangi şablondan oluşturuldu
    template_id = Column(Integer, ForeignKey("task_template.id"), nullable=False)
    
    # Görev başlığı (şablondan kopyalanabilir veya özel yazılabilir)
    title = Column(String, nullable=True)
    
    # Görev açıklaması
    description = Column(Text, nullable=True)

    # Görevin zamanı (YYYY-MM-DD HH:MM:SS formatında)
    scheduled_for = Column(DateTime, nullable=False)

    # Görev durumu - Bakıcı tarafından güncellenir
    # Olası değerler: pending | in_progress | done | problem | cancelled
    status = Column(String, default="pending")

    # Eğer durum "problem" ise, sorun mesajı burada saklanır
    problem_message = Column(Text, nullable=True)
    
    # Problem seviyesi: mild | moderate | critical
    problem_severity = Column(String, nullable=True)
    
    # Çözüm notu (sorun çözüldüğünde)
    resolution_note = Column(Text, nullable=True)
    
    # Tamamlama fotoğrafı URL'i
    completion_photo_url = Column(String, nullable=True)
    
    # Değerlendirme puanı (1-5)
    rating = Column(Integer, nullable=True)
    
    # Değerlendirme notu
    review_note = Column(Text, nullable=True)

    # Görev oluşturulma zamanı
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Son güncelleme zamanı (durum değişikliğinde güncellenir)
    updated_at = Column(DateTime, default=datetime.utcnow)

    # Görevi oluşturan kullanıcı (hasta_yakini)
    created_by_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)
    
    # Görevin atandığı kullanıcı (hasta_bakici)
    assigned_to_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)

    # İlişkiler
    # Görevin bağlı olduğu şablon
    template = relationship("TaskTemplate", back_populates="task_instances")

    # Görevin atandığı kullanıcı bilgileri
    assigned_to = relationship(
        "AppUser",
        foreign_keys=[assigned_to_id],
        back_populates="assigned_task_instances"
    )


# ===================================================================
# BİLDİRİM MODELİ (Notification)
# ===================================================================
class Notification(Base):
    """
    Kullanıcılara gönderilen bildirimleri saklar.
    Örnek bildirimler:
    - Bakıcıya: "Yeni görev atandı"
    - Hasta yakınına: "Görev tamamlandı" veya "Görevde sorun var"
    """
    __tablename__ = "notification"

    # Birincil anahtar
    id = Column(Integer, primary_key=True, index=True)
    
    # Bildirimin gönderildiği kullanıcı
    user_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)
    
    # Bildirim mesajı
    message = Column(Text, nullable=False)
    
    # Bildirim okundu mu?
    is_read = Column(Boolean, default=False)
    
    # Bildirim oluşturulma zamanı
    created_at = Column(DateTime, default=datetime.utcnow)

    # İlişki - Bildirimin sahibi kullanıcı
    user = relationship("AppUser", back_populates="created_notifications")


# ===================================================================
# AKTİVİTE KAYDI MODELİ (ActivityLog)
# ===================================================================
class ActivityLog(Base):
    """
    Kullanıcı aktivitelerini kaydeder.
    Hangi kullanıcı ne zaman hangi işlemi yaptı?
    Örnek: "Görev oluşturma", "Görev güncelleme", "Durum değiştirme"
    Denetim (audit) ve sonuç analizi için kullanılır.
    """
    __tablename__ = "activity_log"

    # Birincil anahtar
    id = Column(Integer, primary_key=True, index=True)
    
    # İşlemi yapan kullanıcı
    user_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)
    
    # Yapılan işlem (CREATE_TASK, UPDATE_TASK_STATUS, DELETE_TASK, vb.)
    action = Column(String, nullable=False)
    
    # İşlem yapılan nesne tipi (TaskInstance, TaskTemplate, vb.) - opsiyonel
    entity_type = Column(String, nullable=True)
    
    # İşlem yapılan nesnenin ID'si - opsiyonel
    entity_id = Column(Integer, nullable=True)
    
    # İşlemin yapıldığı zaman
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Ek detaylar (JSON veya metin olarak)
    details = Column(Text, nullable=True)

    # İlişki - Aktiviteyi yapan kullanıcı
    user = relationship("AppUser", back_populates="activity_logs")


# ===================================================================
# MESAJ MODELİ (Message)
# ===================================================================
class Message(Base):
    """
    Kullanıcılar arası mesajlaşma.
    Hasta yakını ve bakıcı arasında iletişim.
    """
    __tablename__ = "message"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("app_user.id"), nullable=False)
    content = Column(Text, nullable=True)
    sent_at = Column(DateTime, default=datetime.utcnow)
    is_edited = Column(Boolean, default=False)
    edited_at = Column(DateTime, nullable=True)
    is_deleted = Column(Boolean, default=False)
    is_read = Column(Boolean, default=False)

    # İlişkiler
    sender = relationship("AppUser", foreign_keys=[sender_id])
    receiver = relationship("AppUser", foreign_keys=[receiver_id])
    attachments = relationship("MessageAttachment", back_populates="message")


# ===================================================================
# MESAJ EKİ MODELİ (MessageAttachment)
# ===================================================================
class MessageAttachment(Base):
    """
    Mesajlara eklenen dosyalar.
    """
    __tablename__ = "message_attachment"

    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey("message.id"), nullable=False)
    file_type = Column(String, nullable=False)  # image, document, etc.
    file_path = Column(String, nullable=False)
    file_name = Column(String, nullable=False)
    file_size = Column(Integer, nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)

    # İlişki
    message = relationship("Message", back_populates="attachments")
