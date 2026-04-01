import json
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.historial import Historial


async def register_event(
    db: AsyncSession,
    *,
    usuario: str,
    tipo_accion: str,
    entidad_tipo: str,
    entidad_id: str,
    descripcion: str,
    datos_anteriores: dict[str, Any] | None = None,
    datos_nuevos: dict[str, Any] | None = None,
) -> Historial:
    """Registra una entrada en el historial. Nunca falla silenciosamente."""
    entry = Historial(
        usuario=usuario,
        tipo_accion=tipo_accion,
        entidad_tipo=entidad_tipo,
        entidad_id=entidad_id,
        descripcion=descripcion,
        datos_anteriores=json.dumps(datos_anteriores, default=str) if datos_anteriores else None,
        datos_nuevos=json.dumps(datos_nuevos, default=str) if datos_nuevos else None,
    )
    db.add(entry)
    await db.flush()
    return entry
