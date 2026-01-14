# ===================================================================
# İSTATİSTİK ROUTER'I (statistics.py)
# ===================================================================
# Hasta yakını ve bakıcı için istatistik endpoint'leri.
# ===================================================================

from typing import List
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from .. import schemas, crud, models
from ..database import get_db

router = APIRouter(prefix="/statistics", tags=["statistics"])


# ===================================================================
# HASTA YAKINI İSTATİSTİKLERİ
# ===================================================================

@router.get("/relative/{user_id}/overview")
def get_relative_overview(user_id: int, db: Session = Depends(get_db)):
    """
    Hasta yakını için genel istatistik özeti.
    """
    user = crud.get_user(db, user_id)
    if not user or user.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hasta yakını bulunamadı."
        )
    
    # Oluşturulan toplam görev sayısı
    total_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id
    ).count()
    
    # Tamamlanan görevler
    completed_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "done"
    ).count()
    
    # Bekleyen görevler
    pending_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "pending"
    ).count()
    
    # Sorunlu görevler
    problem_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "problem"
    ).count()
    
    # Tamamlanma oranı
    completion_rate = (completed_tasks / total_tasks * 100) if total_tasks > 0 else 0
    
    # Ortalama puan
    avg_rating = db.query(func.avg(models.TaskInstance.rating)).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.rating.isnot(None)
    ).scalar() or 0
    
    return {
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "pending_tasks": pending_tasks,
        "problem_tasks": problem_tasks,
        "completion_rate": round(completion_rate, 1),
        "average_rating": round(float(avg_rating), 1)
    }


@router.get("/relative/{user_id}/caregiver-performance")
def get_caregiver_performance(user_id: int, db: Session = Depends(get_db)):
    """
    Bakıcı performans analizi (hasta yakını için).
    """
    user = crud.get_user(db, user_id)
    if not user or user.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hasta yakını bulunamadı."
        )
    
    # Bu hasta yakınının görev atadığı bakıcıları bul
    caregivers = db.query(models.TaskInstance.assigned_to_id).filter(
        models.TaskInstance.created_by_id == user_id
    ).distinct().all()
    
    performance_data = []
    for (caregiver_id,) in caregivers:
        caregiver = crud.get_user(db, caregiver_id)
        if not caregiver:
            continue
            
        # Toplam görev
        total = db.query(models.TaskInstance).filter(
            models.TaskInstance.created_by_id == user_id,
            models.TaskInstance.assigned_to_id == caregiver_id
        ).count()
        
        # Tamamlanan görev
        completed = db.query(models.TaskInstance).filter(
            models.TaskInstance.created_by_id == user_id,
            models.TaskInstance.assigned_to_id == caregiver_id,
            models.TaskInstance.status == "done"
        ).count()
        
        # Ortalama puan
        avg_rating = db.query(func.avg(models.TaskInstance.rating)).filter(
            models.TaskInstance.created_by_id == user_id,
            models.TaskInstance.assigned_to_id == caregiver_id,
            models.TaskInstance.rating.isnot(None)
        ).scalar() or 0
        
        performance_data.append({
            "caregiver_id": caregiver_id,
            "caregiver_name": caregiver.full_name,
            "total_tasks": total,
            "completed_tasks": completed,
            "completion_rate": round(completed / total * 100, 1) if total > 0 else 0,
            "average_rating": round(float(avg_rating), 1)
        })
    
    return performance_data


@router.get("/relative/{user_id}/problem-trends")
def get_problem_trends(user_id: int, days: int = 30, db: Session = Depends(get_db)):
    """
    Sorun trendleri analizi (hasta yakını için).
    """
    user = crud.get_user(db, user_id)
    if not user or user.role != "hasta_yakini":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hasta yakını bulunamadı."
        )
    
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # Seviyeye göre sorun sayıları
    hafif_count = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "problem",
        models.TaskInstance.problem_severity == "mild",
        models.TaskInstance.created_at >= start_date
    ).count()
    
    orta_count = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "problem",
        models.TaskInstance.problem_severity == "moderate",
        models.TaskInstance.created_at >= start_date
    ).count()
    
    ciddi_count = db.query(models.TaskInstance).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "problem",
        models.TaskInstance.problem_severity == "critical",
        models.TaskInstance.created_at >= start_date
    ).count()
    
    total_problems = hafif_count + orta_count + ciddi_count
    
    # En çok sorun yaşanan görevler
    problem_tasks = db.query(
        models.TaskInstance.title,
        func.count(models.TaskInstance.id).label('count')
    ).filter(
        models.TaskInstance.created_by_id == user_id,
        models.TaskInstance.status == "problem",
        models.TaskInstance.created_at >= start_date
    ).group_by(models.TaskInstance.title).order_by(func.count(models.TaskInstance.id).desc()).limit(5).all()
    
    top_problem_tasks = [
        {"task_name": task[0] or "İsimsiz Görev", "count": task[1]}
        for task in problem_tasks
    ]
    
    return {
        "period_days": days,
        "total_problems": total_problems,
        "severity_distribution": {
            "hafif": hafif_count,
            "orta": orta_count,
            "ciddi": ciddi_count
        },
        "top_problem_tasks": top_problem_tasks
    }


# ===================================================================
# BAKICI İSTATİSTİKLERİ
# ===================================================================

@router.get("/caregiver/{user_id}/overview")
def get_caregiver_overview(user_id: int, db: Session = Depends(get_db)):
    """
    Bakıcı için genel istatistik özeti.
    """
    user = crud.get_user(db, user_id)
    if not user or user.role != "hasta_bakici":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bakıcı bulunamadı."
        )
    
    # Toplam atanan görev
    total_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.assigned_to_id == user_id
    ).count()
    
    # Tamamlanan görevler
    completed_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.assigned_to_id == user_id,
        models.TaskInstance.status == "done"
    ).count()
    
    # Bekleyen görevler
    pending_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.assigned_to_id == user_id,
        models.TaskInstance.status == "pending"
    ).count()
    
    # Bugünkü görevler
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)
    
    today_tasks = db.query(models.TaskInstance).filter(
        models.TaskInstance.assigned_to_id == user_id,
        models.TaskInstance.scheduled_for >= today_start,
        models.TaskInstance.scheduled_for < today_end
    ).count()
    
    # Ortalama puan
    avg_rating = db.query(func.avg(models.TaskInstance.rating)).filter(
        models.TaskInstance.assigned_to_id == user_id,
        models.TaskInstance.rating.isnot(None)
    ).scalar() or 0
    
    return {
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "pending_tasks": pending_tasks,
        "today_tasks": today_tasks,
        "completion_rate": round(completed_tasks / total_tasks * 100, 1) if total_tasks > 0 else 0,
        "average_rating": round(float(avg_rating), 1)
    }


@router.get("/caregiver/{user_id}/weekly-summary")
def get_caregiver_weekly_summary(user_id: int, db: Session = Depends(get_db)):
    """
    Bakıcı için haftalık özet.
    """
    user = crud.get_user(db, user_id)
    if not user or user.role != "hasta_bakici":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bakıcı bulunamadı."
        )
    
    weekly_data = []
    today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    
    for i in range(7):
        day_start = today - timedelta(days=i)
        day_end = day_start + timedelta(days=1)
        
        total = db.query(models.TaskInstance).filter(
            models.TaskInstance.assigned_to_id == user_id,
            models.TaskInstance.scheduled_for >= day_start,
            models.TaskInstance.scheduled_for < day_end
        ).count()
        
        completed = db.query(models.TaskInstance).filter(
            models.TaskInstance.assigned_to_id == user_id,
            models.TaskInstance.scheduled_for >= day_start,
            models.TaskInstance.scheduled_for < day_end,
            models.TaskInstance.status == "done"
        ).count()
        
        weekly_data.append({
            "date": day_start.strftime("%Y-%m-%d"),
            "day_name": day_start.strftime("%A"),
            "total_tasks": total,
            "completed_tasks": completed
        })
    
    return weekly_data
