from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.historial import Historial
from app.schemas.historial import HistorialResponse
from app.utils.auth import get_current_user

router = APIRouter(prefix="/historial", tags=["historial"])


@router.get("", response_model=list[HistorialResponse])
async def list_historial(
    fecha: date | None = Query(None),
    tipo: str | None = Query(None),
    entidad_id: str | None = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[HistorialResponse]:
    """Lista entradas de historial con filtros opcionales."""
    stmt = select(Historial).order_by(Historial.timestamp.desc()).limit(limit)
    if fecha:
        from sqlalchemy import func
        stmt = stmt.where(func.date(Historial.timestamp) == fecha)
    if tipo:
        stmt = stmt.where(Historial.tipo_accion == tipo)
    if entidad_id:
        stmt = stmt.where(Historial.entidad_id == entidad_id)
    result = await db.execute(stmt)
    return [HistorialResponse.model_validate(h) for h in result.scalars().all()]


@router.get("/obra/{obra_id}", response_model=list[HistorialResponse])
async def historial_obra(
    obra_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[HistorialResponse]:
    """Historial completo de una obra."""
    stmt = (
        select(Historial)
        .where(Historial.entidad_tipo == "obra")
        .where(Historial.entidad_id == obra_id)
        .order_by(Historial.timestamp.desc())
    )
    result = await db.execute(stmt)
    return [HistorialResponse.model_validate(h) for h in result.scalars().all()]


@router.get("/operario/{operario_id}", response_model=list[HistorialResponse])
async def historial_operario(
    operario_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[HistorialResponse]:
    """Historial completo de un operario."""
    stmt = (
        select(Historial)
        .where(Historial.entidad_tipo == "operario")
        .where(Historial.entidad_id == operario_id)
        .order_by(Historial.timestamp.desc())
    )
    result = await db.execute(stmt)
    return [HistorialResponse.model_validate(h) for h in result.scalars().all()]
