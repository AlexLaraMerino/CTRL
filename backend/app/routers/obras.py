import json
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.asignacion import Asignacion
from app.models.obra import Obra
from app.schemas.obra import ObraCreate, ObraResponse, ObraUpdate
from app.schemas.operario import OperarioResponse
from app.models.operario import Operario
from app.services.historial_service import register_event
from app.utils.auth import get_current_user

router = APIRouter(prefix="/obras", tags=["obras"])


def _obra_to_response(obra: Obra) -> ObraResponse:
    """Convierte modelo ORM a schema, parseando tipos_instalacion."""
    data = {c.name: getattr(obra, c.name) for c in obra.__table__.columns}
    if data.get("tipos_instalacion"):
        try:
            data["tipos_instalacion"] = json.loads(data["tipos_instalacion"])
        except (json.JSONDecodeError, TypeError):
            data["tipos_instalacion"] = None
    return ObraResponse(**data)


@router.get("", response_model=list[ObraResponse])
async def list_obras(
    estado: str | None = None,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[ObraResponse]:
    """Lista todas las obras, con filtro opcional por estado."""
    stmt = select(Obra)
    if estado:
        stmt = stmt.where(Obra.estado == estado)
    result = await db.execute(stmt)
    return [_obra_to_response(o) for o in result.scalars().all()]


@router.get("/activas", response_model=list[ObraResponse])
async def list_obras_activas(
    fecha: date | None = None,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[ObraResponse]:
    """Obras activas en un día concreto (para el mapa)."""
    stmt = select(Obra).where(Obra.estado == "activa")
    if fecha:
        stmt = stmt.where(
            (Obra.fecha_inicio <= fecha) | (Obra.fecha_inicio.is_(None))
        ).where(
            (Obra.fecha_fin_prevista >= fecha) | (Obra.fecha_fin_prevista.is_(None))
        )
    result = await db.execute(stmt)
    return [_obra_to_response(o) for o in result.scalars().all()]


@router.get("/{obra_id}", response_model=ObraResponse)
async def get_obra(
    obra_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> ObraResponse:
    """Detalle completo de una obra."""
    obra = await db.get(Obra, obra_id)
    if not obra:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Obra no encontrada")
    return _obra_to_response(obra)


@router.post("", response_model=ObraResponse, status_code=status.HTTP_201_CREATED)
async def create_obra(
    body: ObraCreate,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> ObraResponse:
    """Crea una nueva obra."""
    data = body.model_dump()
    if data.get("tipos_instalacion"):
        data["tipos_instalacion"] = json.dumps(data["tipos_instalacion"])
    obra = Obra(**data)
    db.add(obra)
    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="obra",
        entidad_tipo="obra",
        entidad_id=obra.id,
        descripcion=f"Obra creada: {obra.nombre}",
        datos_nuevos=body.model_dump(),
    )
    await db.commit()
    await db.refresh(obra)
    return _obra_to_response(obra)


@router.patch("/{obra_id}", response_model=ObraResponse)
async def update_obra(
    obra_id: str,
    body: ObraUpdate,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> ObraResponse:
    """Modifica campos de una obra."""
    obra = await db.get(Obra, obra_id)
    if not obra:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Obra no encontrada")
    old_data = {c.name: getattr(obra, c.name) for c in obra.__table__.columns}
    updates = body.model_dump(exclude_unset=True)
    if "tipos_instalacion" in updates and updates["tipos_instalacion"] is not None:
        updates["tipos_instalacion"] = json.dumps(updates["tipos_instalacion"])
    for field, value in updates.items():
        setattr(obra, field, value)
    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="obra",
        entidad_tipo="obra",
        entidad_id=obra.id,
        descripcion=f"Obra actualizada: {obra.nombre}",
        datos_anteriores=old_data,
        datos_nuevos=updates,
    )
    await db.commit()
    await db.refresh(obra)
    return _obra_to_response(obra)


@router.get("/{obra_id}/operarios", response_model=list[OperarioResponse])
async def get_obra_operarios(
    obra_id: str,
    fecha: date = Query(...),
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[OperarioResponse]:
    """Operarios asignados a una obra en una fecha concreta."""
    stmt = (
        select(Operario)
        .join(Asignacion, Asignacion.operario_id == Operario.id)
        .where(Asignacion.obra_id == obra_id)
        .where(Asignacion.fecha == fecha)
        .where(Asignacion.activo.is_(True))
    )
    result = await db.execute(stmt)
    operarios = result.scalars().all()
    responses = []
    for op in operarios:
        data = {c.name: getattr(op, c.name) for c in op.__table__.columns}
        if data.get("especialidades"):
            try:
                data["especialidades"] = json.loads(data["especialidades"])
            except (json.JSONDecodeError, TypeError):
                data["especialidades"] = None
        responses.append(OperarioResponse(**data))
    return responses
