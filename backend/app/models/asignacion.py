from datetime import date

from sqlalchemy import Boolean, Date, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, gen_uuid


class Asignacion(TimestampMixin, Base):
    __tablename__ = "asignaciones"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    operario_id: Mapped[str] = mapped_column(String(36), ForeignKey("operarios.id"), nullable=False)
    obra_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("obras.id"))
    fecha: Mapped[date] = mapped_column(Date, nullable=False)
    es_ruta: Mapped[bool] = mapped_column(Boolean, default=False)
    obras_ruta: Mapped[str | None] = mapped_column(Text)  # JSON array de UUIDs
    latitud_libre: Mapped[float | None] = mapped_column(Float)
    longitud_libre: Mapped[float | None] = mapped_column(Float)
    notas: Mapped[str | None] = mapped_column(Text)
    created_by: Mapped[str | None] = mapped_column(String(100))
    activo: Mapped[bool] = mapped_column(Boolean, default=True)
