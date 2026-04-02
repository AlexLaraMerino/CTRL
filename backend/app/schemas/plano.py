from datetime import datetime

from pydantic import BaseModel


class PlanoResponse(BaseModel):
    id: str
    obra_id: str
    nombre: str
    ruta_original: str
    ruta_anotada: str | None = None
    version: int
    anotado_por: str | None = None
    anotado_en: datetime | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
