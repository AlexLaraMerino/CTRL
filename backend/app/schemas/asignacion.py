from datetime import date, datetime

from pydantic import BaseModel


class AsignacionCreate(BaseModel):
    operario_id: str
    obra_id: str | None = None
    fecha: date
    es_ruta: bool = False
    obras_ruta: list[str] | None = None
    latitud_libre: float | None = None
    longitud_libre: float | None = None
    notas: str | None = None


class AsignacionResponse(BaseModel):
    id: str
    operario_id: str
    obra_id: str | None = None
    fecha: date
    es_ruta: bool
    obras_ruta: list[str] | None = None
    latitud_libre: float | None = None
    longitud_libre: float | None = None
    notas: str | None = None
    created_by: str | None = None
    activo: bool
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class CopiarDiaRequest(BaseModel):
    fecha_origen: date
    fecha_destino: date


class ExtenderSemanaRequest(BaseModel):
    fecha_origen: date
