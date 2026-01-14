# ===================================================================
# BİLDİRİM ROUTER'I (notifications.py)
# ===================================================================
# Kullanıcı bildirimlerini yönetir.
# Endpoint'ler: GET /{user_id}, PATCH /{notification_id}/read, POST /{user_id}/read_all
# ===================================================================

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import schemas, crud, models
from ..database import get_db

# Router tanımlaması - Tüm endpoint'ler /notifications prefix'i ile başlar
router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/{user_id}", response_model=List[schemas.NotificationRead])
def list_notifications(user_id: int, db: Session = Depends(get_db)):
    """
    Bir kullanıcının tüm bildirimlerini listeler.
    En yeni bildirim en üstte olacak şekilde sıralı gelir.
    
    Kullanım senaryosu:
    - Kullanıcı bildirim sayfasını açtığında tüm bildirimleri görür
    - Hem okunmuş hem de okunmamış bildirimler gelir
    
    Path parametresi:
    - user_id: Bildirimleri görüntülenecek kullanıcının ID'si
    
    Response: Bildirim listesi (mesaj, okundu mu, tarih, vb.)
    """
    # Önce kullanıcı var mı kontrol et
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )

    # Kullanıcının bildirimlerini getir
    notifs = crud.list_notifications_for_user(db, user_id=user_id)
    return notifs


@router.patch("/{notification_id}/read", response_model=schemas.NotificationRead)
def mark_notification_read(notification_id: int, db: Session = Depends(get_db)):
    """
    Tek bir bildirimi "okundu" olarak işaretler.
    
    Kullanım senaryosu:
    - Kullanıcı bir bildirime tıkladığında okundu olarak işaretlemek
    
    Path parametresi:
    - notification_id: Okundu olarak işaretlenecek bildirimin ID'si
    
    Response: Güncellenmiş bildirim (is_read=True)
    """
    notif = db.get(models.Notification, notification_id)
    if not notif:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bildirim bulunamadı.",
        )

    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif


@router.post("/{user_id}/read_all", response_model=List[schemas.NotificationRead])
def mark_all_notifications_read(user_id: int, db: Session = Depends(get_db)):
    """
    Kullanıcının TÜM bildirimlerini toplu olarak "okundu" işaretler.
    
    Kullanım senaryosu:
    - Kullanıcı bildirim sayfasını açtığında otomatik olarak çağrılabilir
    - Veya "Tümünü okundu işaretle" butonu ile
    
    Path parametresi:
    - user_id: Bildirimleri okundu yapılacak kullanıcının ID'si
    
    Response: Güncellenmiş bildirim listesi (tümü is_read=True)
    """
    # Önce kullanıcı var mı kontrol et
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )

    # Tüm bildirimleri getir ve okundu yap
    notifs = crud.list_notifications_for_user(db, user_id=user_id)
    for n in notifs:
        n.is_read = True
    db.commit()
    
    # Güncellenmiş listeyi döndür
    return crud.list_notifications_for_user(db, user_id=user_id)
