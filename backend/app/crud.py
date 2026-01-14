# ===================================================================
# CRUD İŞLEMLERİ (crud.py)
# ===================================================================
# Create, Read, Update, Delete (CRUD) işlemlerini içerir.
# Veritabanı ile etkileşim için tüm fonksiyonlar burada tanımlıdır.
# ===================================================================

from typing import Optional, List
from datetime import datetime

from sqlalchemy.orm import Session
from passlib.context import CryptContext

from . import models, schemas

# Şifre hashleme için pbkdf2_sha256 algoritması kullanılıyor
# bcrypt yerine tercih edilmiş (daha hızlı ve güvenli)
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


# ===================================================================
# ŞİFRE YÖNETİMİ FONKSİYONLARI
# ===================================================================

def get_password_hash(password: str) -> str:
    """
    Düz metin şifreyi hashleyerek güvenli bir şekilde saklamak için kullanılır.
    Şifreler asla düz metin olarak veritabanına kaydedilmez.
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Kullanıcının girdiği şifrenin veritabanındaki hashlenmiş şifre ile eşleşip
    eşleşmediğini kontrol eder. Giriş işlemlerinde kullanılır.
    """
    return pwd_context.verify(plain_password, hashed_password)


# ===================================================================
# KULLANICI (USER) CRUD İŞEMLERİ
# ===================================================================

def get_user_by_email(db: Session, email: str) -> Optional[models.AppUser]:
    """
    Email adresine göre kullanıcı arar.
    Giriş işlemlerinde ve kullanıcı var mı kontrolünde kullanılır.
    """
    return db.query(models.AppUser).filter(models.AppUser.email == email).first()


def get_user(db: Session, user_id: int) -> Optional[models.AppUser]:
    """
    Kullanıcı ID'sine göre kullanıcı bilgilerini getirir.
    """
    return db.get(models.AppUser, user_id)


def list_users_by_role(db: Session, role: str) -> List[models.AppUser]:
    """
    Belirli bir role sahip tüm kullanıcıları listeler.
    Örnek: Tüm hasta_bakici'leri listele.
    """
    return db.query(models.AppUser).filter(models.AppUser.role == role).all()


def create_user(db: Session, user_in: schemas.UserCreate) -> models.AppUser:
    """
    Yeni kullanıcı oluşturur.
    Şifre hashlenip güvenli bir şekilde saklanır.
    Kayıt (register) işlemlerinde kullanılır.
    """
    hashed_pw = get_password_hash(user_in.password)
    db_user = models.AppUser(
        full_name=user_in.full_name,
        email=user_in.email,
        role=user_in.role,
        hashed_password=hashed_pw,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


# ===================================================================
# GÖREV ŞABLONU (TASK TEMPLATE) CRUD İŞEMLERİ
# ===================================================================

def create_task_template(db: Session, template_in: schemas.TaskTemplateCreate) -> models.TaskTemplate:
    """
    Yeni görev şablonu oluşturur.
    Sadece hasta_yakini kullanıcıları şablon oluşturabilir.
    Tekrar eden görevler için kullanılır.
    """
    db_template = models.TaskTemplate(
        title=template_in.title,
        description=template_in.description,
        default_time=template_in.default_time,
        created_by_id=template_in.created_by_id,
    )
    db.add(db_template)
    db.commit()
    db.refresh(db_template)
    return db_template


def list_task_templates(db: Session) -> List[models.TaskTemplate]:
    """
    Tüm görev şablonlarını listeler.
    Görev oluşturma ekranında şablonları göstermek için kullanılır.
    """
    return db.query(models.TaskTemplate).all()


def get_task_template(db: Session, template_id: int) -> Optional[models.TaskTemplate]:
    """
    Belirli bir şablon ID'sine göre şablon bilgilerini getirir.
    """
    return db.get(models.TaskTemplate, template_id)


def update_task_template(
    db: Session, template: models.TaskTemplate, template_in: schemas.TaskTemplateBase
) -> models.TaskTemplate:
    """
    Mevcut bir görev şablonunu günceller.
    Başlık, açıklama ve varsayılan saat değiştirilebilir.
    """
    template.title = template_in.title
    template.description = template_in.description
    template.default_time = template_in.default_time
    db.commit()
    db.refresh(template)
    return template


def delete_task_template(db: Session, template: models.TaskTemplate) -> None:
    """
    Bir görev şablonunu siler.
    Not: Alternatif olarak is_active=False yaparak pasifleştirilebilir.
    """
    db.delete(template)
    db.commit()


# ===================================================================
# GÖREV ÖRNEĞİ (TASK INSTANCE) CRUD İŞEMLERİ
# ===================================================================

def create_task_instance(db: Session, task_in: schemas.TaskInstanceCreate) -> models.TaskInstance:
    """
    Yeni görev örneği oluşturur (görev ataması).
    Hasta yakını bir şablondan görev oluşturur ve bakıcıya atar.
    Başlangıç durumu "pending" olarak ayarlanır.
    """
    db_task = models.TaskInstance(
        template_id=task_in.template_id,
        title=task_in.title,
        description=task_in.description,
        created_by_id=task_in.created_by_id,
        assigned_to_id=task_in.assigned_to_id,
        scheduled_for=task_in.scheduled_for,
        status="pending",  # Yeni görev beklemede başlar
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    return db_task


def list_tasks_for_user(
    db: Session,
    user_id: int,
    status: Optional[str] = None,
    sort_by_scheduled: bool = True,
) -> List[models.TaskInstance]:
    """
    Bir kullanıcıya (bakıcıya) atanmış görevleri listeler.
    assigned_to_id = user_id olan görevleri döndürür.
    
    Parametreler:
    - user_id: Görevleri görüntülenecek kullanıcı (bakıcı)
    - status: Durum filtreleme (pending, done, vb.) - opsiyonel
    - sort_by_scheduled: Tarihe göre sırala (en yakın tarih önce)
    """
    q = db.query(models.TaskInstance).filter(models.TaskInstance.assigned_to_id == user_id)
    if status:
        q = q.filter(models.TaskInstance.status == status)
    if sort_by_scheduled:
        q = q.order_by(models.TaskInstance.scheduled_for.asc())
    return q.all()


def list_tasks_created_by(
    db: Session,
    user_id: int,
    status: Optional[str] = None,
    sort_by_scheduled: bool = True,
) -> List[models.TaskInstance]:
    """
    Bir kullanıcının (hasta yakınının) oluşturduğu görevleri listeler.
    created_by_id = user_id olan görevleri döndürür.
    Hasta yakını atadığı tüm görevleri görmek için kullanır.
    
    Parametreler:
    - user_id: Görevleri oluşturan kullanıcı (hasta yakını)
    - status: Durum filtreleme - opsiyonel
    - sort_by_scheduled: Tarihe göre sırala
    """
    q = db.query(models.TaskInstance).filter(models.TaskInstance.created_by_id == user_id)
    if status:
        q = q.filter(models.TaskInstance.status == status)
    if sort_by_scheduled:
        q = q.order_by(models.TaskInstance.scheduled_for.asc())
    return q.all()


def get_task_instance(db: Session, task_id: int) -> Optional[models.TaskInstance]:
    """
    Görev ID'sine göre belirli bir görev örneğini getirir.
    """
    return db.get(models.TaskInstance, task_id)

from datetime import datetime
def update_task_instance_time(db: Session, task: models.TaskInstance, new_time: datetime):
    """
    Bir görevin zamanlanmış tarih/saatini günceller.
    Hasta yakını görev zamanını değiştirdiğinde kullanılır.
    Zaman değişince görev durumu otomatik "pending" olarak sıfırlanır.
    """
    task.scheduled_for = new_time
    task.status = "pending"  # Yeni zamana taşınan görev beklemede duruma döner
    db.commit()
    db.refresh(task)
    return task


def update_task_status(
    db: Session, task: models.TaskInstance, new_status: str, 
    problem_message: Optional[str] = None,
    problem_severity: Optional[str] = None,
    resolution_note: Optional[str] = None
) -> models.TaskInstance:
    """
    Bir görevin durumunu günceller.
    Bakıcı görevi başlattığında, tamamladığında veya sorun bildirdiğinde kullanılır.
    
    Parametreler:
    - task: Güncellenecek görev
    - new_status: Yeni durum (pending, in_progress, done, problem, cancelled)
    - problem_message: Sorun mesajı (sadece durum "problem" ise doldurulur)
    - problem_severity: Sorun seviyesi (mild, moderate, critical)
    - resolution_note: Çözüm notu
    """
    task.status = new_status
    if new_status == "problem":
        task.problem_message = problem_message
        task.problem_severity = problem_severity
    if resolution_note:
        task.resolution_note = resolution_note
    task.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(task)
    return task


def delete_task_instance(db: Session, task: models.TaskInstance) -> None:
    """
    Bir görev örneğini siler.
    Hasta yakını kendi oluşturduğu görevleri silebilir.
    """
    db.delete(task)
    db.commit()


# ===================================================================
# BİLDİRİM (NOTIFICATION) CRUD İŞEMLERİ
# ===================================================================

def create_notification(
    db: Session,
    user_id: int,
    message: str,
) -> models.Notification:
    """
    Yeni bir bildirim oluşturur.
    Kullanıcılara önemli olaylar hakkında bilgi vermek için kullanılır.
    
    Bildirim senaryoları:
    - Bakıcıya: "Yeni görev atandı", "Görev zamanı değişti"
    - Hasta yakınına: "Görev tamamlandı", "Görevde sorun var"
    """
    notif = models.Notification(
        user_id=user_id,
        message=message,
        is_read=False,  # Yeni bildirim okunmamış olarak başlar
        created_at=datetime.utcnow(),
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif


def list_notifications_for_user(db: Session, user_id: int) -> List[models.Notification]:
    """
    Bir kullanıcının tüm bildirimlerini listeler.
    En yeni bildirimler önce gelir (created_at azalan sırada).
    """
    return (
        db.query(models.Notification)
        .filter(models.Notification.user_id == user_id)
        .order_by(models.Notification.created_at.desc())
        .all()
    )


# ===================================================================
# AKTİVİTE KAYDI (ACTIVITY LOG) CRUD İŞEMLERİ
# ===================================================================

def log_activity(
    db: Session,
    user_id: int,
    action: str,
    entity_type: str | None = None,
    entity_id: int | None = None,
    details: str | None = None,
) -> models.ActivityLog:
    """
    Kullanıcı aktivitesini kaydeder.
    Sistemde yapılan önemli işlemlerin kayıt altına alınmasını sağlar.
    Denetim (audit) ve raporlama amacıyla kullanılır.
    
    Parametreler:
    - user_id: İşlemi yapan kullanıcı
    - action: Yapılan işlem (CREATE_TASK, UPDATE_TASK_STATUS, vb.)
    - entity_type: İşlem yapılan nesne tipi (TaskInstance, TaskTemplate, vb.)
    - entity_id: İşlem yapılan nesnenin ID'si
    - details: Ek detaylar (JSON veya metin)
    
    Örnek kullanım:
    log_activity(db, user_id=1, action="CREATE_TASK", 
                 entity_type="TaskInstance", entity_id=42,
                 details="assigned_to=5, scheduled_for=2025-11-26")
    """
    log = models.ActivityLog(
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        timestamp=datetime.utcnow(),
        details=details,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


# ===================================================================
# DIĞER YARDİMCI FONKSİYONLAR
# ===================================================================

def list_caregivers(db: Session):
    """
    Rolü 'hasta_bakici' olan tüm kullanıcıları döndürür.
    Hasta yakını görev atarken bakıcı listesini göstermek için kullanılır.
    /users/caregivers endpoint'i bunu kullanır.
    """
    return db.query(models.AppUser).filter(models.AppUser.role == "hasta_bakici").all()


def list_relatives(db: Session):
    """
    Rolü 'hasta_yakini' olan tüm kullanıcıları döndürür.
    Bakıcı mesaj göndermek istediğinde hasta yakını listesi için kullanılır.
    /users/relatives endpoint'i bunu kullanır.
    """
    return db.query(models.AppUser).filter(models.AppUser.role == "hasta_yakini").all()