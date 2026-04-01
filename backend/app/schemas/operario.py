from datetime import datetime

from pydantic import BaseModel


class OperarioCreate(BaseModel):
    nombre: str
    telefono: str | None = None
    especialidades: list[str] | None = None
    activo: bool = True
    notas: str | None = None


class OperarioUpdate(BaseModel):
    nombre: str | None = None
    telefono: str | None = None
    especialidades: list[str] | None = None
    activo: bool | None = None
    notas: str | None = None


class OperarioResponse(BaseModel):
    id: str
    nombre: str
    telefono: str | None = None
    especialidades: list[str] | None = None
    activo: bool
    notas: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
