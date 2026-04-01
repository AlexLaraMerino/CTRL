import json
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.asignacion import Asignacion
from app.models.operario import Operario
from app.schemas.asignacion import AsignacionResponse
from app.schemas.operario import OperarioCreate, OperarioResponse, OperarioUpdate
from app.services.historial_service import register_event
from app.utils.auth import get_current_user

router = APIRouter(prefix="/operarios", tags=["operarios"])


def _operario_to_response(op: Operario) -> OperarioResponse:
    data = {c.name: getattr(op, c.name) for c in op.__table__.columns}
    if data.get("especialidades"):
        try:
            data["especialidades"] = json.loads(data["especialidades"])
        except (json.JSONDecodeError, TypeError):
            data["especialidades"] = None
    return OperarioResponse(**data)


def _asignacion_to_response(a: Asignacion) -> AsignacionResponse:
    data = {c.name: getattr(a, c.name) for c in a.__table__.columns}
    if data.get("obras_ruta"):
        try:
            data["obras_ruta"] = json.loads(data["obras_ruta"])
        except (json.JSONDecodeError, TypeError):
            data["obras_ruta"] = None
    return AsignacionResponse(**data)


@router.get("", response_model=list[OperarioResponse])
async def list_operarios(
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[OperarioResponse]:
    """Lista todos los operarios activos."""
    result = await db.execute(select(Operario).where(Operario.activo.is_(True)))
    return [_operario_to_response(o) for o in result.scalars().all()]


@router.get("/{operario_id}", response_model=OperarioResponse)
async def get_operario(
    operario_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> OperarioResponse:
    """Detalle de un operario."""
    op = await db.get(Operario, operario_id)
    if not op:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Operario no encontrado")
    return _operario_to_response(op)


@router.post("", response_model=OperarioResponse, status_code=status.HTTP_201_CREATED)
async def create_operario(
    body: OperarioCreate,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> OperarioResponse:
    """Crea un operario."""
    data = body.model_dump()
    if data.get("especialidades"):
        data["especialidades"] = json.dumps(data["especialidades"])
    op = Operario(**data)
    db.add(op)
    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="operario",
        entidad_tipo="operario",
        entidad_id=op.id,
        descripcion=f"Operario creado: {op.nombre}",
        datos_nuevos=body.model_dump(),
    )
    await db.commit()
    await db.refresh(op)
    return _operario_to_response(op)


@router.patch("/{operario_id}", response_model=OperarioResponse)
async def update_operario(
    operario_id: str,
    body: OperarioUpdate,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> OperarioResponse:
    """Modifica datos de un operario."""
    op = await db.get(Operario, operario_id)
    if not op:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Operario no encontrado")
    old_data = {c.name: getattr(op, c.name) for c in op.__table__.columns}
    updates = body.model_dump(exclude_unset=True)
    if "especialidades" in updates and updates["especialidades"] is not None:
        updates["especialidades"] = json.dumps(updates["especialidades"])
    for field, value in updates.items():
        setattr(op, field, value)
    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="operario",
        entidad_tipo="operario",
        entidad_id=op.id,
        descripcion=f"Operario actualizado: {op.nombre}",
        datos_anteriores=old_data,
        datos_nuevos=updates,
    )
    await db.commit()
    await db.refresh(op)
    return _operario_to_response(op)


@router.get("/{operario_id}/asignaciones", response_model=list[AsignacionResponse])
async def get_operario_asignaciones(
    operario_id: str,
    desde: date | None = Query(None),
    hasta: date | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[AsignacionResponse]:
    """Historial de asignaciones del operario."""
    stmt = (
        select(Asignacion)
        .where(Asignacion.operario_id == operario_id)
        .where(Asignacion.activo.is_(True))
        .order_by(Asignacion.fecha.desc())
    )
    if desde:
        stmt = stmt.where(Asignacion.fecha >= desde)
    if hasta:
        stmt = stmt.where(Asignacion.fecha <= hasta)
    result = await db.execute(stmt)
    return [_asignacion_to_response(a) for a in result.scalars().all()]
