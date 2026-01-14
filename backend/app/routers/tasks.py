# ===================================================================
# GÖREV ROUTER'I (tasks.py)
# ===================================================================
# Görev şablonları ve görev örnekleri (atanmış görevler) yönetimi.
# İki ana bölüm:
# 1. Task Templates (Şablonlar): /tasks/templates/*
# 2. Task Instances (Atanmış Görevler): /tasks/instances/*
# ===================================================================

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import schemas, crud, models
from ..database import get_db

# Router tanımlaması - Tüm endpoint'ler /tasks prefix'i ile başlar
router = APIRouter(prefix="/tasks", tags=["tasks"])


# ===================================================================
# GÖREV ŞABLONU (TASK TEMPLATE) ENDPOINT'LERİ
# ===================================================================

@router.post("/templates", response_model=schemas.TaskTemplateRead)
def create_template(template_in: schemas.TaskTemplateCreate, db: Session = Depends(get_db)):
    """
    Yeni görev şablonu oluşturur.
    
    SADECE hasta_yakini rolündeki kullanıcılar şablon oluşturabilir.
    Şablon, tekrar eden görevler için kullanılır.
    Örnek: "Kahvaltı hazırla", "İlaç ver", "Oda temizliği"
    
    Request body:
    - title: Görev başlığı
    - description: Görev açıklaması (opsiyonel)
    - default_time: Varsayılan saat "HH:MM" formatında (opsiyonel)
    - created_by_id: Şablonu oluşturan kullanıcı ID (hasta_yakini olmalı)
    
    İşlem adımları:
    1. Kullanıcı var mı ve hasta_yakini mi kontrol et
    2. Şablonu oluştur
    3. Aktivite kaydı tut
    4. Şablon bilgilerini döndür
    """
    creator = crud.get_user(db, template_in.created_by_id)
    if not creator:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="created_by_id kullanıcısı bulunamadı.",
        )

    if creator.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece hasta yakını görev şablonu oluşturabilir.",
        )

    template = crud.create_task_template(db, template_in)

    crud.log_activity(
        db,
        user_id=creator.id,
        action="CREATE_TASK_TEMPLATE",
        entity_type="TaskTemplate",
        entity_id=template.id,
        details=f"title={template.title}",
    )

    return template


@router.get("/templates", response_model=List[schemas.TaskTemplateRead])
def list_templates(db: Session = Depends(get_db)):
    """
    Tüm görev şablonlarını listeler.
    
    Kullanım senaryosu:
    - Hasta yakını görev oluşturmak istediğinde mevcut şablonları görür
    - Görev atama ekranında dropdown/liste doldurulur
    
    Response: Tüm görev şablonlarının listesi
    """
    return crud.list_task_templates(db)


@router.get("/templates/{template_id}", response_model=schemas.TaskTemplateRead)
def get_template(template_id: int, db: Session = Depends(get_db)):
    """
    Belirli bir görev şablonunun detaylarını getirir.
    
    Kullanım senaryosu:
    - Şablon detaylarını görüntüleme
    - Şablon düzenleme ekranında mevcut bilgileri getirme
    
    Path parametresi:
    - template_id: Şablon ID'si
    
    Response: Şablon detayları (başlık, açıklama, varsayılan saat, vb.)
    """
    template = crud.get_task_template(db, template_id)
    if not template:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Şablon bulunamadı.",
        )
    return template


@router.put("/templates/{template_id}", response_model=schemas.TaskTemplateRead)
def update_template(
    template_id: int,
    template_in: schemas.TaskTemplateBase,
    db: Session = Depends(get_db),
):
    """
    Mevcut bir görev şablonunu günceller.
    
    SADECE şablonu oluşturan hasta_yakini kullanıcısı güncelleyebilir.
    
    Path parametresi:
    - template_id: Güncellenecek şablon ID'si
    
    Request body:
    - title: Yeni görev başlığı
    - description: Yeni açıklama
    - default_time: Yeni varsayılan saat
    
    İşlem adımları:
    1. Şablon var mı kontrol et
    2. Oluşturan kullanıcı hasta_yakini mi kontrol et
    3. Şablonu güncelle
    4. Aktivite kaydı tut
    5. Güncellenmiş şablonu döndür
    """
    template = crud.get_task_template(db, template_id)
    if not template:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Şablon bulunamadı.",
        )

    creator = crud.get_user(db, template.created_by_id)
    if not creator:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Oluşturucu kullanıcı bulunamadı.",
        )

    if creator.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece hasta yakını şablon düzenleyebilir.",
        )

    updated = crud.update_task_template(db, template, template_in)

    crud.log_activity(
        db,
        user_id=creator.id,
        action="UPDATE_TASK_TEMPLATE",
        entity_type="TaskTemplate",
        entity_id=updated.id,
        details=f"title={updated.title}",
    )

    return updated


# ===================================================================
# GÖREV ÖRNEĞİ (TASK INSTANCE) ENDPOINT'LERİ
# Atanmış görevlerin yönetimi
# ===================================================================

@router.post("/instances", response_model=schemas.TaskInstanceRead)
def create_task_instance(task_in: schemas.TaskInstanceCreate, db: Session = Depends(get_db)):
    """
    Yeni görev örneği oluşturur (görev atama).
    
    SADECE hasta_yakini kullanıcıları görev atayabilir.
    Görev SADECE hasta_bakici kullanıcılara atanabilir.
    
    Request body:
    - template_id: Hangi şablondan görev oluşturulacak
    - created_by_id: Görevi oluşturan kullanıcı (hasta_yakini)
    - assigned_to_id: Görevin atandığı kullanıcı (hasta_bakici)
    - scheduled_for: Görev zamanı (ISO format: YYYY-MM-DDTHH:MM:SS)
    
    İşlem adımları:
    1. Oluşturan kullanıcı hasta_yakini mi kontrol et
    2. Atanan kullanıcı hasta_bakici mi kontrol et
    3. Görev örneği oluştur
    4. Aktivite kaydı tut
    5. Bakıcıya bildirim gönder
    6. Görev bilgilerini döndür
    """
    creator = crud.get_user(db, task_in.created_by_id)
    if not creator:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="created_by_id kullanıcısı bulunamadı.",
        )

    if creator.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece hasta yakını görev atayabilir.",
        )

    assignee = crud.get_user(db, task_in.assigned_to_id)
    if not assignee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="assigned_to_id kullanıcısı bulunamadı.",
        )

    if assignee.role != "hasta_bakici":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Görev sadece hasta bakıcıya atanabilir.",
        )

    # (İstersen burada template var mı yok mu diye de kontrol eklenebilir)
    task = crud.create_task_instance(db, task_in)

    # Activity Log
    crud.log_activity(
        db,
        user_id=creator.id,
        action="CREATE_TASK",
        entity_type="TaskInstance",
        entity_id=task.id,
        details=f"assigned_to={assignee.id}, scheduled_for={task.scheduled_for}",
    )

    # Bildirim: Hasta bakıcıya -> yeni görev atandı
    message = f"Yeni görev atandı. Tarih/Saat: {task.scheduled_for.isoformat()}"
    crud.create_notification(db, user_id=assignee.id, message=message)

    return task


@router.get("/assigned/{user_id}", response_model=List[schemas.TaskInstanceRead])
def list_assigned_tasks(
    user_id: int,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Bir kullanıcıya atanmış görevleri listeler.
    
    Kullanım senaryosu:
    - Bakıcı kendi görev listesini görür
    - Hangi görevleri yapması gerektiğini takip eder
    
    Path parametresi:
    - user_id: Görevleri listelenecek kullanıcı (genelde hasta_bakici)
    
    Query parametresi (opsiyonel):
    - status: Durum filtresi (?status=pending veya ?status=done)
    
    Response: Görevler zamana göre sıralı (en yakın tarih önce)
    """
    return crud.list_tasks_for_user(db, user_id=user_id, status=status, sort_by_scheduled=True)


@router.get("/created/{user_id}", response_model=List[schemas.TaskInstanceRead])
def list_created_tasks(
    user_id: int,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Bir kullanıcının oluşturduğu görevleri listeler.
    
    Kullanım senaryosu:
    - Hasta yakını atadığı tüm görevleri görür
    - Hangi görevlerin tamamlandığını, hangilerinde sorun olduğunu takip eder
    
    Path parametresi:
    - user_id: Görevleri oluşturan kullanıcı (hasta_yakini)
    
    Query parametresi (opsiyonel):
    - status: Durum filtresi
    
    Response: Görevler zamana göre sıralı
    """
    return crud.list_tasks_created_by(db, user_id=user_id, status=status, sort_by_scheduled=True)


@router.put("/instances/{task_id}", response_model=schemas.TaskInstanceRead)
def update_task_instance_time(
    task_id: int,
    payload: schemas.TaskInstanceUpdate,
    db: Session = Depends(get_db),
):
    """
    Bir görevin zamanlanmış tarih/saatini günceller.
    
    SADECE hasta_yakini, KENDİ OLUŞTURDUĞU görevlerin zamanını değiştirebilir.
    
    Kullanım senaryosu:
    - Hasta yakını planları değişti ve görev saatini kaydırmak istiyor
    - Görev durumu otomatik "pending"e döner
    
    Path parametresi:
    - task_id: Güncellenecek görev ID'si
    
    Request body:
    - scheduled_for: Yeni tarih/saat (ISO format)
    
    İşlem adımları:
    1. Görev var mı kontrol et
    2. Görevi oluşturan kullanıcı hasta_yakini mi kontrol et
    3. Görev zamanını güncelle
    4. Aktivite kaydı tut
    5. Bakıcıya bildirim gönder
    6. Güncellenmiş görevi döndür
    """
    task = crud.get_task_instance(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görev bulunamadı.",
        )

    creator = crud.get_user(db, task.created_by_id)
    if not creator:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görevin oluşturucusu bulunamadı.",
        )

    updated_task = crud.update_task_instance_time(db, task, payload.scheduled_for)

    # Activity Log
    crud.log_activity(
        db,
        user_id=creator.id,
        action="UPDATE_TASK",
        entity_type="TaskInstance",
        entity_id=task.id,
        details=f"scheduled_for={updated_task.scheduled_for}",
    )

    # Bildirim: Hasta bakıcıya -> görev zamanı değişti
    message = f"Bir görevin zamanı güncellendi. Yeni tarih/saat: {updated_task.scheduled_for.isoformat()}"
    crud.create_notification(db, user_id=task.assigned_to_id, message=message)

    return updated_task


@router.delete("/instances/{task_id}")
def delete_task_instance(
    task_id: int,
    user_id: int,  # hasta yakını id'si (şimdilik query param olarak alıyoruz)
    db: Session = Depends(get_db),
):
    """
    Bir görevi siler.
    
    SADECE hasta_yakini, KENDİ OLUŞTURDUĞU görevleri silebilir.
    
    Kullanım senaryosu:
    - Hasta yakını yanlışlıkla oluşturduğu veya artık gerekmeyen görevi siler
    
    Path parametresi:
    - task_id: Silinecek görev ID'si
    
    Query parametresi:
    - user_id: Silme işlemini yapan kullanıcı (hasta_yakini)
    
    İşlem adımları:
    1. Görev var mı kontrol et
    2. Kullanıcı hasta_yakini mi kontrol et
    3. Görev bu kullanıcı tarafından oluşturulmuş mu kontrol et
    4. Görevi sil
    5. Aktivite kaydı tut
    6. Bakıcıya bildirim gönder
    7. Başarı mesajı döndür
    """
    task = crud.get_task_instance(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görev bulunamadı.",
        )

    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )

    if user.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece hasta yakını görev silebilir.",
        )

    if task.created_by_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu görev bu kullanıcı tarafından oluşturulmamış.",
        )

    crud.delete_task_instance(db, task)

    # Activity Log
    crud.log_activity(
        db,
        user_id=user.id,
        action="DELETE_TASK",
        entity_type="TaskInstance",
        entity_id=task_id,
        details=None,
    )

    # Bildirim: Hasta bakıcıya -> görev silindi
    message = "Size atanmış bir görev silindi."
    crud.create_notification(db, user_id=task.assigned_to_id, message=message)

    return {"detail": "Görev silindi."}


# ===================================================================
# GÖREV DURUM GÜNCELLEME (Sadece hasta_bakici)
# ===================================================================

@router.patch("/instances/status", response_model=schemas.TaskInstanceRead)
def update_task_status(
    payload: schemas.TaskStatusUpdate,
    db: Session = Depends(get_db),
):
    """
    Bir görevin durumunu günceller.
    
    SADECE hasta_bakici, KENDİSİNE ATANMIŞ görevlerin durumunu değiştirebilir.
    
    Kullanım senaryoları:
    - Bakıcı göreve başladı: pending -> in_progress
    - Bakıcı görevi tamamladı: in_progress -> done
    - Bakıcı sorunla karşılaştı: in_progress -> problem
    - Görev iptal edildi: * -> cancelled
    
    Request body:
    - task_id: Güncellenecek görev ID'si
    - user_id: Güncelleme yapan kullanıcı (hasta_bakici olmalı)
    - status: Yeni durum (pending/in_progress/done/problem/cancelled)
    - problem_message: Sorun açıklaması (sadece status="problem" ise)
    
    İşlem adımları:
    1. Kullanıcı hasta_bakici mi kontrol et
    2. Görev var mı kontrol et
    3. Görev bu kullanıcıya atanmış mı kontrol et
    4. Görev durumunu güncelle
    5. Aktivite kaydı tut
    6. Hasta yakınına bildirim gönder
    7. Güncellenmiş görevi döndür
    """

    user = crud.get_user(db, payload.user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )

    if user.role != "hasta_bakici":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece hasta bakıcı görev durumunu güncelleyebilir.",
        )

    task = crud.get_task_instance(db, payload.task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görev bulunamadı.",
        )

    if task.assigned_to_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu görev bu kullanıcıya atanmış değil.",
        )

    updated = crud.update_task_status(
        db,
        task,
        payload.status,
        problem_message=payload.problem_message,
        problem_severity=payload.problem_severity,
        resolution_note=payload.resolution_note,
    )

    # Activity Log
    crud.log_activity(
        db,
        user_id=user.id,
        action="UPDATE_TASK_STATUS",
        entity_type="TaskInstance",
        entity_id=task.id,
        details=f"status={payload.status}, problem_message={payload.problem_message}",
    )

    # Bildirim: Hasta yakınına görev durumu değişikliğini bildir
    owner_id = task.created_by_id
    
    # Duruma göre farklı bildirim mesajları oluştur
    if payload.status == "done":
        # Görev başarıyla tamamlandı
        msg = f"Bir görev tamamlandı. Tarih/Saat: {task.scheduled_for.isoformat()}"
    elif payload.status == "problem":
        # Görevde sorun var - acil dikkat gerekebilir
        msg = f"Bir görevde sorun bildirildi: {payload.problem_message or ''}"
    else:
        # Diğer durum değişiklikleri (in_progress, cancelled, vb.)
        msg = f"Bir görevin durumu güncellendi: {payload.status}"

    crud.create_notification(db, user_id=owner_id, message=msg)

    return updated


# ===================================================================
# GÖREV DEĞERLENDİRME (Sadece hasta_yakini)
# ===================================================================

@router.patch("/instances/{task_id}/rating", response_model=schemas.TaskInstanceRead)
def rate_task(
    task_id: int,
    current_user_id: int,
    rating: int,
    review_note: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Bir görevi değerlendirir.
    
    SADECE hasta_yakini, KENDİ OLUŞTURDUĞU görevleri değerlendirebilir.
    Görev tamamlanmış (done) durumda olmalıdır.
    
    Query parametreleri:
    - current_user_id: Değerlendirme yapan kullanıcı (hasta_yakini)
    - rating: Puan (1-5 arası)
    - review_note: Değerlendirme notu (opsiyonel)
    """
    user = crud.get_user(db, current_user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )

    if user.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece hasta yakını görev değerlendirebilir.",
        )

    task = crud.get_task_instance(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görev bulunamadı.",
        )

    if task.created_by_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu görev bu kullanıcı tarafından oluşturulmamış.",
        )

    if task.status != "done":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sadece tamamlanmış görevler değerlendirilebilir.",
        )

    if rating < 1 or rating > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Puan 1-5 arasında olmalıdır.",
        )

    task.rating = rating
    task.review_note = review_note
    db.commit()
    db.refresh(task)

    # Bakıcıya bildirim gönder
    msg = f"Tamamladığınız görev değerlendirildi: {rating}/5 yıldız"
    crud.create_notification(db, user_id=task.assigned_to_id, message=msg)

    return task


# ===================================================================
# KULLANICI GÖREV ŞABLONLARINI LİSTELEME
# ===================================================================

@router.get("/templates/user/{user_id}", response_model=List[schemas.TaskTemplateRead])
def list_user_templates(user_id: int, db: Session = Depends(get_db)):
    """
    Belirli bir kullanıcının oluşturduğu görev şablonlarını listeler.
    """
    templates = db.query(models.TaskTemplate).filter(
        models.TaskTemplate.created_by_id == user_id
    ).all()
    return templates