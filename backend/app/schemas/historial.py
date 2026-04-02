from datetime import datetime

from pydantic import BaseModel


class HistorialResponse(BaseModel):
    id: str
    timestamp: datetime
    usuario: str
    tipo_accion: str
    entidad_tipo: str
    entidad_id: str
    descripcion: str
    datos_anteriores: str | None = None
    datos_nuevos: str | None = None

    model_config = {"from_attributes": True}
