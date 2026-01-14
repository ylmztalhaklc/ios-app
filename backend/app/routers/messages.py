# ===================================================================
# MESAJ ROUTER'I (messages.py)
# ===================================================================
# Kullanıcılar arası mesajlaşma endpoint'leri.
# ===================================================================

from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
import os
import shutil

from .. import schemas, crud, models
from ..database import get_db

router = APIRouter(prefix="/messages", tags=["messages"])

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "..", "uploads", "messages")
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/send", response_model=schemas.MessageRead)
def send_message(message_in: schemas.MessageCreate, db: Session = Depends(get_db)):
    """
    Yeni mesaj gönderir.
    """
    # Gönderen ve alıcı kullanıcıları kontrol et
    sender = crud.get_user(db, message_in.sender_id)
    receiver = crud.get_user(db, message_in.receiver_id)
    
    if not sender or not receiver:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Gönderen veya alıcı bulunamadı."
        )
    
    # Mesajı oluştur
    db_message = models.Message(
        sender_id=message_in.sender_id,
        receiver_id=message_in.receiver_id,
        content=message_in.content,
        sent_at=datetime.utcnow(),
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    
    return db_message


@router.get("/conversation/{other_user_id}", response_model=List[schemas.MessageRead])
def get_conversation(
    other_user_id: int,
    current_user_id: int,
    db: Session = Depends(get_db)
):
    """
    İki kullanıcı arasındaki konuşmayı getirir.
    """
    messages = db.query(models.Message).filter(
        or_(
            and_(
                models.Message.sender_id == current_user_id,
                models.Message.receiver_id == other_user_id
            ),
            and_(
                models.Message.sender_id == other_user_id,
                models.Message.receiver_id == current_user_id
            )
        ),
        models.Message.is_deleted == False
    ).order_by(models.Message.sent_at.asc()).all()
    
    # Alınan mesajları okundu olarak işaretle
    for msg in messages:
        if msg.receiver_id == current_user_id and not msg.is_read:
            msg.is_read = True
    db.commit()
    
    return messages


@router.get("/conversations/{user_id}", response_model=List[schemas.ConversationPreview])
def get_conversations(user_id: int, db: Session = Depends(get_db)):
    """
    Kullanıcının tüm konuşmalarını listeler.
    """
    # Kullanıcının dahil olduğu tüm mesajları bul
    messages = db.query(models.Message).filter(
        or_(
            models.Message.sender_id == user_id,
            models.Message.receiver_id == user_id
        ),
        models.Message.is_deleted == False
    ).order_by(models.Message.sent_at.desc()).all()
    
    # Konuşmaları grupla
    conversations = {}
    for msg in messages:
        other_id = msg.receiver_id if msg.sender_id == user_id else msg.sender_id
        if other_id not in conversations:
            other_user = crud.get_user(db, other_id)
            unread = db.query(models.Message).filter(
                models.Message.sender_id == other_id,
                models.Message.receiver_id == user_id,
                models.Message.is_read == False,
                models.Message.is_deleted == False
            ).count()
            
            conversations[other_id] = {
                "other_user_id": other_id,
                "other_user_name": other_user.full_name if other_user else "Bilinmeyen",
                "other_user_role": other_user.role if other_user else "unknown",
                "last_message": msg.content,
                "last_message_time": msg.sent_at,
                "unread_count": unread
            }
    
    return list(conversations.values())


@router.put("/{message_id}", response_model=schemas.MessageRead)
def update_message(
    message_id: int,
    current_user_id: int,
    content: str,
    db: Session = Depends(get_db)
):
    """
    Mesajı düzenler (sadece gönderen yapabilir).
    """
    message = db.get(models.Message, message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mesaj bulunamadı."
        )
    
    if message.sender_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu mesajı düzenleme yetkiniz yok."
        )
    
    message.content = content
    message.is_edited = True
    message.edited_at = datetime.utcnow()
    db.commit()
    db.refresh(message)
    
    return message


@router.delete("/{message_id}")
def delete_message(
    message_id: int,
    current_user_id: int,
    db: Session = Depends(get_db)
):
    """
    Mesajı siler (soft delete - sadece gönderen yapabilir).
    """
    message = db.get(models.Message, message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mesaj bulunamadı."
        )
    
    if message.sender_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu mesajı silme yetkiniz yok."
        )
    
    message.is_deleted = True
    db.commit()
    
    return {"message": "Mesaj silindi"}


@router.post("/upload/{message_id}")
async def upload_attachment(
    message_id: int,
    current_user_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Mesaja dosya eki yükler.
    """
    message = db.get(models.Message, message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mesaj bulunamadı."
        )
    
    if message.sender_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu mesaja ek yükleme yetkiniz yok."
        )
    
    # Dosya türünü belirle
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
        file_type = 'image'
    else:
        file_type = 'document'
    
    # Dosyayı kaydet
    file_name = f"{message_id}_{datetime.utcnow().timestamp()}{file_ext}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Veritabanına kaydet
    attachment = models.MessageAttachment(
        message_id=message_id,
        file_type=file_type,
        file_path=f"/uploads/messages/{file_name}",
        file_name=file.filename,
        file_size=os.path.getsize(file_path),
    )
    db.add(attachment)
    db.commit()
    db.refresh(attachment)
    
    return {"message": "Dosya yüklendi", "attachment_id": attachment.id}


@router.delete("/attachment/{attachment_id}")
def delete_attachment(
    attachment_id: int,
    current_user_id: int,
    db: Session = Depends(get_db)
):
    """
    Mesaj ekini siler.
    """
    attachment = db.get(models.MessageAttachment, attachment_id)
    if not attachment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ek bulunamadı."
        )
    
    message = db.get(models.Message, attachment.message_id)
    if message.sender_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu eki silme yetkiniz yok."
        )
    
    # Dosyayı sil
    file_path = os.path.join(os.path.dirname(UPLOAD_DIR), attachment.file_path.lstrip('/uploads/'))
    if os.path.exists(file_path):
        os.remove(file_path)
    
    db.delete(attachment)
    db.commit()
    
    return {"message": "Ek silindi"}
