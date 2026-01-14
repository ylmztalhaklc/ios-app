# ===================================================================
# DOSYA YÜKLEME ROUTER'I (uploads.py)
# ===================================================================
# Görev fotoğrafı ve diğer dosya yükleme işlemleri.
# ===================================================================

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
import os
import shutil

from .. import crud, models
from ..database import get_db

router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "..", "uploads")
TASK_PHOTOS_DIR = os.path.join(UPLOAD_DIR, "task_photos")
os.makedirs(TASK_PHOTOS_DIR, exist_ok=True)


@router.post("/task-photo/{task_id}")
async def upload_task_photo(
    task_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Görev tamamlama fotoğrafı yükler.
    """
    task = crud.get_task_instance(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görev bulunamadı."
        )
    
    # Dosya uzantısını kontrol et
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Desteklenmeyen dosya formatı. Sadece jpg, jpeg, png, gif, webp kabul edilir."
        )
    
    # Dosya adı oluştur
    file_name = f"task_{task_id}_{datetime.utcnow().timestamp()}{file_ext}"
    file_path = os.path.join(TASK_PHOTOS_DIR, file_name)
    
    # Dosyayı kaydet
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # URL'i veritabanına kaydet
    photo_url = f"/uploads/task_photos/{file_name}"
    task.completion_photo_url = photo_url
    db.commit()
    
    return {"message": "Fotoğraf yüklendi", "photo_url": photo_url}


@router.delete("/task-photo/{task_id}")
def delete_task_photo(task_id: int, db: Session = Depends(get_db)):
    """
    Görev fotoğrafını siler.
    """
    task = crud.get_task_instance(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görev bulunamadı."
        )
    
    if not task.completion_photo_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görevde fotoğraf bulunmuyor."
        )
    
    # Dosyayı sil
    file_name = task.completion_photo_url.split('/')[-1]
    file_path = os.path.join(TASK_PHOTOS_DIR, file_name)
    if os.path.exists(file_path):
        os.remove(file_path)
    
    # URL'i kaldır
    task.completion_photo_url = None
    db.commit()
    
    return {"message": "Fotoğraf silindi"}


@router.get("/task_photos/{file_name}")
async def get_task_photo(file_name: str):
    """
    Görev fotoğrafını döndürür.
    """
    file_path = os.path.join(TASK_PHOTOS_DIR, file_name)
    if not os.path.exists(file_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dosya bulunamadı."
        )
    
    return FileResponse(file_path)
