from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, Field

from app.db.session import get_db
from app.models.user import User, UserProfile
from app.core.deps import get_current_user

router = APIRouter()


class ProfileUpdateRequest(BaseModel):
    daily_word_count: int = Field(..., ge=1, le=50)


class ProfileResponse(BaseModel):
    daily_word_count: int
    current_level_id: int
    streak_count: int
    longest_streak: int
    total_words_learned: int

    model_config = {"from_attributes": True}


@router.get("/me/profile", response_model=ProfileResponse)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(UserProfile).where(UserProfile.user_id == current_user.id))
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil bulunamadı")
    return profile


@router.patch("/me/profile", response_model=ProfileResponse)
async def update_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(UserProfile).where(UserProfile.user_id == current_user.id))
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil bulunamadı")

    profile.daily_word_count = payload.daily_word_count
    await db.commit()
    await db.refresh(profile)
    return profile


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Hesabı ve tüm ilişkili verileri kalıcı olarak siler (App Store 5.1.1(v) uyumu).
    users tablosundaki tüm ilişkili kayıtlar ON DELETE CASCADE ile otomatik silinir.
    """
    result = await db.execute(select(User).where(User.id == current_user.id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kullanıcı bulunamadı")

    await db.delete(user)
    await db.commit()
    return None
