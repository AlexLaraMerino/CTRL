import json
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.asignacion import Asignacion
from app.schemas.asignacion import (
    AsignacionCreate,
    AsignacionResponse,
    CopiarDiaRequest,
    ExtenderSemanaRequest,
)
from app.services.historial_service import register_event
from app.utils.auth import get_current_user

router = APIRouter(prefix="/asignaciones", tags=["asignaciones"])


def _to_response(a: Asignacion) -> AsignacionResponse:
    data = {c.name: getattr(a, c.name) for c in a.__table__.columns}
    if data.get("obras_ruta"):
        try:
            data["obras_ruta"] = json.loads(data["obras_ruta"])
        except (json.JSONDecodeError, TypeError):
            data["obras_ruta"] = None
    return AsignacionResponse(**data)


@router.get("", response_model=list[AsignacionResponse])
async def list_asignaciones(
    fecha: date = Query(...),
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[AsignacionResponse]:
    """Todas las asignaciones activas de un día (para el mapa)."""
    stmt = (
        select(Asignacion)
        .where(Asignacion.fecha == fecha)
        .where(Asignacion.activo.is_(True))
    )
    result = await db.execute(stmt)
    return [_to_response(a) for a in result.scalars().all()]


@router.post("", response_model=AsignacionResponse, status_code=status.HTTP_201_CREATED)
async def create_asignacion(
    body: AsignacionCreate,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> AsignacionResponse:
    """Crea una asignación para un operario en un día."""
    # Desactivar asignaciones previas del mismo operario en la misma fecha
    stmt = (
        select(Asignacion)
        .where(Asignacion.operario_id == body.operario_id)
        .where(Asignacion.fecha == body.fecha)
        .where(Asignacion.activo.is_(True))
    )
    result = await db.execute(stmt)
    for old in result.scalars().all():
        old.activo = False

    data = body.model_dump()
    if data.get("obras_ruta"):
        data["obras_ruta"] = json.dumps(data["obras_ruta"])
    data["created_by"] = user
    asig = Asignacion(**data)
    db.add(asig)
    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="asignacion",
        entidad_tipo="asignacion",
        entidad_id=asig.id,
        descripcion=f"Asignación creada: operario {body.operario_id} en fecha {body.fecha}",
        datos_nuevos=body.model_dump(),
    )
    await db.commit()
    await db.refresh(asig)
    return _to_response(asig)


@router.delete("/{asignacion_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_asignacion(
    asignacion_id: str,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> None:
    """Elimina lógicamente una asignación (marca inactiva)."""
    asig = await db.get(Asignacion, asignacion_id)
    if not asig:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Asignación no encontrada")
    old_data = {c.name: getattr(asig, c.name) for c in asig.__table__.columns}
    asig.activo = False
    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="asignacion",
        entidad_tipo="asignacion",
        entidad_id=asig.id,
        descripcion=f"Asignación desactivada: {asig.id}",
        datos_anteriores=old_data,
        datos_nuevos={"activo": False},
    )
    await db.commit()


@router.post("/copiar-dia", response_model=list[AsignacionResponse])
async def copiar_dia(
    body: CopiarDiaRequest,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> list[AsignacionResponse]:
    """Copia todas las asignaciones de una fecha a otra."""
    # Leer asignaciones de la fecha origen
    stmt = (
        select(Asignacion)
        .where(Asignacion.fecha == body.fecha_origen)
        .where(Asignacion.activo.is_(True))
    )
    result = await db.execute(stmt)
    originals = result.scalars().all()

    if not originals:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No hay asignaciones en {body.fecha_origen}",
        )

    # Desactivar asignaciones existentes en la fecha destino
    stmt_dest = (
        select(Asignacion)
        .where(Asignacion.fecha == body.fecha_destino)
        .where(Asignacion.activo.is_(True))
    )
    result_dest = await db.execute(stmt_dest)
    for existing in result_dest.scalars().all():
        existing.activo = False

    # Crear nuevas asignaciones
    new_asigs = []
    for orig in originals:
        new = Asignacion(
            operario_id=orig.operario_id,
            obra_id=orig.obra_id,
            fecha=body.fecha_destino,
            es_ruta=orig.es_ruta,
            obras_ruta=orig.obras_ruta,
            latitud_libre=orig.latitud_libre,
            longitud_libre=orig.longitud_libre,
            notas=orig.notas,
            created_by=user,
        )
        db.add(new)
        new_asigs.append(new)

    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="asignacion",
        entidad_tipo="asignacion",
        entidad_id="bulk",
        descripcion=f"Copiadas {len(new_asigs)} asignaciones de {body.fecha_origen} a {body.fecha_destino}",
        datos_nuevos=body.model_dump(),
    )
    await db.commit()
    for a in new_asigs:
        await db.refresh(a)
    return [_to_response(a) for a in new_asigs]


@router.post("/extender-semana", response_model=list[AsignacionResponse])
async def extender_semana(
    body: ExtenderSemanaRequest,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> list[AsignacionResponse]:
    """Extiende las asignaciones de un día al resto de días laborables de la semana."""
    # Leer asignaciones del día origen
    stmt = (
        select(Asignacion)
        .where(Asignacion.fecha == body.fecha_origen)
        .where(Asignacion.activo.is_(True))
    )
    result = await db.execute(stmt)
    originals = result.scalars().all()

    if not originals:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No hay asignaciones en {body.fecha_origen}",
        )

    # Calcular días laborables restantes de la semana (lunes=0 a viernes=4)
    weekday = body.fecha_origen.weekday()
    target_dates = []
    for d in range(weekday + 1, 5):  # hasta viernes
        target_dates.append(body.fecha_origen + timedelta(days=d - weekday))

    if not target_dates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No quedan días laborables en la semana",
        )

    all_new = []
    for target_date in target_dates:
        # Desactivar existentes en el día destino
        stmt_dest = (
            select(Asignacion)
            .where(Asignacion.fecha == target_date)
            .where(Asignacion.activo.is_(True))
        )
        result_dest = await db.execute(stmt_dest)
        for existing in result_dest.scalars().all():
            existing.activo = False

        # Copiar cada asignación
        for orig in originals:
            new = Asignacion(
                operario_id=orig.operario_id,
                obra_id=orig.obra_id,
                fecha=target_date,
                es_ruta=orig.es_ruta,
                obras_ruta=orig.obras_ruta,
                latitud_libre=orig.latitud_libre,
                longitud_libre=orig.longitud_libre,
                notas=orig.notas,
                created_by=user,
            )
            db.add(new)
            all_new.append(new)

    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="asignacion",
        entidad_tipo="asignacion",
        entidad_id="bulk",
        descripcion=f"Extendidas {len(originals)} asignaciones de {body.fecha_origen} a {len(target_dates)} días",
        datos_nuevos={"fecha_origen": str(body.fecha_origen), "dias_destino": [str(d) for d in target_dates]},
    )
    await db.commit()
    for a in all_new:
        await db.refresh(a)
    return [_to_response(a) for a in all_new]
