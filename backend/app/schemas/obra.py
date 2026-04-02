from datetime import date, datetime

from pydantic import BaseModel


class ObraCreate(BaseModel):
    nombre: str
    direccion: str | None = None
    latitud: float | None = None
    longitud: float | None = None
    estado: str = "activa"
    tipos_instalacion: list[str] | None = None
    carpeta_servidor: str | None = None
    notas: str | None = None
    fecha_inicio: date | None = None
    fecha_fin_prevista: date | None = None


class ObraUpdate(BaseModel):
    nombre: str | None = None
    direccion: str | None = None
    latitud: float | None = None
    longitud: float | None = None
    estado: str | None = None
    tipos_instalacion: list[str] | None = None
    carpeta_servidor: str | None = None
    notas: str | None = None
    fecha_inicio: date | None = None
    fecha_fin_prevista: date | None = None


class ObraResponse(BaseModel):
    id: str
    nombre: str
    direccion: str | None = None
    latitud: float | None = None
    longitud: float | None = None
    estado: str
    tipos_instalacion: list[str] | None = None
    carpeta_servidor: str | None = None
    notas: str | None = None
    fecha_inicio: date | None = None
    fecha_fin_prevista: date | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}
