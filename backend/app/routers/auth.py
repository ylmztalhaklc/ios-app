# ===================================================================
# KİMLİK DOĞRULAMA ROUTER'I (auth.py)
# ===================================================================
# Kullanıcı kayıt ve giriş işlemlerini yönetir.
# Endpoint'ler: /auth/register, /auth/login
# ===================================================================

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import schemas, crud, models
from ..database import get_db

# Router tanımlaması - Tüm endpoint'ler /auth prefix'i ile başlar
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.UserRead)
def register(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    """
    Yeni kullanıcı kaydı oluşturur.
    
    İşlem adımları:
    1. Email zaten kayıtlı mı kontrol et
    2. Eğer kayıtlıysa hata döndür
    3. Yeni kullanıcı oluştur (şifre hashlenecek)
    4. Kullanıcı bilgilerini döndür
    
    Request body:
    - full_name: Kullanıcının tam adı
    - email: Email adresi (benzersiz olmalı)
    - role: "hasta_yakini" veya "hasta_bakici"
    - password: Şifre (düz metin - hashlenecek)
    """
    # Aynı email ile kayıtlı kullanıcı var mı kontrol et
    existing = crud.get_user_by_email(db, user_in.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu email ile bir kullanıcı zaten var.",
        )
    # Yeni kullanıcı oluştur
    user = crud.create_user(db, user_in)
    return user


@router.post("/login", response_model=schemas.LoginResponse)
def login(login_req: schemas.LoginRequest, db: Session = Depends(get_db)):
    """
    Kullanıcı girişi yapar.
    
    İşlem adımları:
    1. Email ile kullanıcıyı bul
    2. Kullanıcı yoksa veya şifre yanlışsa hata döndür
    3. Başarılı girişte kullanıcı bilgilerini döndür
    
    Request body:
    - email: Kullanıcının email adresi
    - password: Kullanıcının şifresi
    
    Response:
    - user: Kullanıcı bilgileri (id, email, role, vb.)
    
    Not: Şu anda JWT token kullanılmıyor, basit authentication.
    """
    # Email ile kullanıcıyı bul
    user = crud.get_user_by_email(db, login_req.email)
    # Kullanıcı yoksa veya şifre eşleşmiyorsa hata ver
    if not user or not crud.verify_password(login_req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya şifre hatalı.",
        )
    return schemas.LoginResponse(user=user)
