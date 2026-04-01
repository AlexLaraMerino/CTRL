from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine
from app.models import Base
from app.routers import auth, obras, operarios, asignaciones, historial


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Crea las tablas en el arranque (fase inicial sin Alembic en producción)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="CTRL API",
    description="API de gestión de obras y operarios",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS
origins = [o.strip() for o in settings.allowed_origins.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router)
app.include_router(obras.router)
app.include_router(operarios.router)
app.include_router(asignaciones.router)
app.include_router(historial.router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
