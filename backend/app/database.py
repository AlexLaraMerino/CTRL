from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings

# Adaptar la URL para async: postgresql:// -> postgresql+asyncpg://
# y sqlite:// -> sqlite+aiosqlite://
_url = settings.database_url
if _url.startswith("postgresql://"):
    _url = _url.replace("postgresql://", "postgresql+asyncpg://", 1)
elif _url.startswith("sqlite:///"):
    _url = _url.replace("sqlite:///", "sqlite+aiosqlite:///", 1)

engine = create_async_engine(_url, echo=False)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependencia FastAPI que proporciona una sesión de BD."""
    async with async_session() as session:
        yield session
