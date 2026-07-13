import uuid
from pydantic import BaseModel, EmailStr
from datetime import datetime


class RegisterRequest(BaseModel):
    email: EmailStr
    name: str
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    # SMTP yapılandırılmamışsa (dev modu) kodu buradan dönüyoruz ki test edilebilsin.
    dev_code: str | None = None


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    created_at: datetime
    current_level_id: int | None = None
    placement_completed: bool = False

    model_config = {"from_attributes": True}
