from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from starlette.concurrency import run_in_threadpool

from app.db.session import get_db
from app.models.user import User, UserProfile
from app.models.placement import UserPlacementResult
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse, UserResponse,
    ForgotPasswordRequest, ForgotPasswordResponse, ResetPasswordRequest,
)
from app.core.security import hash_password, verify_password, create_access_token
from app.core.deps import get_current_user
from app.core.config import settings
from app.services.password_reset import generate_code, verify_code, send_reset_email

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Email kontrolü
    result = await db.execute(select(User).where(User.email == payload.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu email adresi zaten kayıtlı",
        )

    # Kullanıcı oluştur
    user = User(
        email=payload.email,
        name=payload.name,
        hashed_password=hash_password(payload.password),
    )
    db.add(user)
    await db.flush()  # id'yi almak için

    # Varsayılan profil oluştur (A1 seviyesi, id=1)
    profile = UserProfile(user_id=user.id, current_level_id=1)
    db.add(profile)
    await db.commit()

    token = create_access_token(subject=user.id)
    return TokenResponse(access_token=token)


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    valid = user is not None and verify_password(payload.password, user.hashed_password)

    if not valid:
        if settings.DETAILED_AUTH_ERRORS:
            # Dev kolaylığı: e-posta yok / şifre yanlış ayrımı
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Bu e-posta ile kayıtlı bir hesap bulunamadı.",
                )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Şifre hatalı.",
            )
        # Üretim (güvenli): tek tip mesaj
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta veya şifre hatalı.",
        )

    token = create_access_token(subject=user.id)
    return TokenResponse(access_token=token)


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
async def forgot_password(payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    if settings.DETAILED_AUTH_ERRORS and not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bu e-posta ile kayıtlı bir hesap bulunamadı.",
        )

    # Kod yalnızca hesap gerçekten varsa üretilip gönderilir.
    dev_code = None
    if user:
        code = generate_code(payload.email)
        sent = await run_in_threadpool(send_reset_email, payload.email, code)
        if not sent:
            dev_code = code  # dev modu: kodu yanıtta göster

    if settings.DETAILED_AUTH_ERRORS:
        message = ("Sıfırlama kodu e-postana gönderildi."
                   if dev_code is None else
                   "E-posta gönderimi yapılandırılmadığı için kod geliştirme modunda gösteriliyor.")
    else:
        # Üretim (güvenli): hesabın var olup olmadığını ele vermeyen tek tip mesaj
        message = "Eğer bu e-posta kayıtlıysa, sıfırlama kodu gönderildi."

    return ForgotPasswordResponse(message=message, dev_code=dev_code)


@router.post("/reset-password", response_model=TokenResponse)
async def reset_password(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    if len(payload.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifre en az 6 karakter olmalı.",
        )

    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Geçerli kod zaten yalnızca var olan hesaba verildiği için, hesap yok/kod
    # yanlış durumlarını tek tip mesajla birleştiriyoruz.
    if not user or not verify_code(payload.email, payload.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kod geçersiz veya süresi dolmuş.",
        )

    user.hashed_password = hash_password(payload.new_password)
    await db.commit()

    token = create_access_token(subject=user.id)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserResponse)
async def me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Profil seviyesi
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    profile = profile_result.scalar_one_or_none()

    # Placement yapıldı mı? (UserPlacementResult satırı varsa)
    placement_result = await db.execute(
        select(UserPlacementResult.id)
        .where(UserPlacementResult.user_id == current_user.id)
        .limit(1)
    )
    placement_completed = placement_result.scalar_one_or_none() is not None

    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        name=current_user.name,
        created_at=current_user.created_at,
        current_level_id=profile.current_level_id if profile else None,
        placement_completed=placement_completed,
    )
