from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.session import engine
from app.models.user import Base
from app.models.progress import TestResult  # noqa: F401  (metadata'ya kayıt için)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)


@app.on_event("startup")
async def _init_db():
    # Yalnızca eksik (model tanımlı) tabloları oluşturur; mevcut tablolara dokunmaz.
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await _seed_levels_if_empty()


async def _seed_levels_if_empty():
    """levels tablosu boşsa 6 CEFR seviyesini ekler (register için gerekli)."""
    from sqlalchemy import select, func
    from app.db.session import AsyncSessionLocal
    from app.models.user import Level

    async with AsyncSessionLocal() as db:
        count = (await db.execute(select(func.count()).select_from(Level))).scalar() or 0
        if count > 0:
            return
        db.add_all([
            Level(id=1, code="A1", name="Beginner",     description="Temel günlük ifadeler ve basit sorular",       sort_order=1),
            Level(id=2, code="A2", name="Elementary",   description="Basit ve rutin konularda iletişim",            sort_order=2),
            Level(id=3, code="B1", name="Intermediate", description="İş, okul ve seyahat gibi konularda iletişim",  sort_order=3),
            Level(id=4, code="B2", name="Upper-Inter",  description="Karmaşık konuları anlama ve akıcı iletişim",   sort_order=4),
            Level(id=5, code="C1", name="Advanced",     description="Karmaşık metinleri anlama, kendiliğinden ifade", sort_order=5),
            Level(id=6, code="C2", name="Mastery",      description="Duyduğunu ve okuduğunu kolayca anlama",         sort_order=6),
        ])
        await db.commit()


@app.get("/health")
def health_check():
    return {"status": "ok"}
