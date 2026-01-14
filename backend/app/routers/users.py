# ===================================================================
# KULLANICI ROUTER'I (users.py)
# ===================================================================
# Kullanıcı bilgilerini sorgulama endpoint'lerini içerir.
# Endpoint'ler: /users/caregivers, /users/{user_id}
# ===================================================================

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from .. import crud, schemas

# Router tanımlaması - Tüm endpoint'ler /users prefix'i ile başlar
router = APIRouter(prefix="/users", tags=["users"])


# Önemli: Sabit path'ler ("/caregivers") dinamik path'lerden ("{user_id}") ÖNCE tanımlanmalı
# Aksi halde FastAPI "caregivers" kelimesini user_id olarak algılar

@router.get("/caregivers", response_model=List[schemas.UserRead])
def list_caregivers(db: Session = Depends(get_db)):
    """
    Rolü 'hasta_bakici' olan tüm kullanıcıları listeler.
    
    Kullanım senaryosu:
    - Hasta yakını görev atarken hangi bakıcılara atayabileceğini görmek için
    - Görev atama ekranında dropdown/liste doldurmak için
    
    Response: Bakıcıların listesi (id, ad, email, vb.)
    """
    return crud.list_caregivers(db)


@router.get("/relatives", response_model=List[schemas.UserRead])
def list_relatives(db: Session = Depends(get_db)):
    """
    Rolü 'hasta_yakini' olan tüm kullanıcıları listeler.
    
    Kullanım senaryosu:
    - Bakıcı mesaj göndermek istediğinde hasta yakını listesi
    
    Response: Hasta yakınlarının listesi (id, ad, email, vb.)
    """
    return crud.list_relatives(db)


@router.get("/{user_id}", response_model=schemas.UserRead)
def get_user(user_id: int, db: Session = Depends(get_db)):
    """
    Belirli bir kullanıcının bilgilerini ID'ye göre getirir.
    
    Kullanım senaryoları:
    - Görev kartlarında karşı tarafın adını göstermek
    - Bakıcı: Görevi atayan hasta yakınının adını görmek
    - Hasta yakını: Görevi yapacak bakıcının adını görmek
    
    Path parametresi:
    - user_id: Kullanıcının ID'si
    
    Response: Kullanıcı bilgileri
    Hata: Kullanıcı bulunamazsa 404 NOT FOUND
    """
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )
    return user
