from datetime import date, datetime, timezone

from sqlalchemy import ARRAY, Date, DateTime, Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, gen_uuid


class Obra(TimestampMixin, Base):
    __tablename__ = "obras"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    nombre: Mapped[str] = mapped_column(Text, nullable=False)
    direccion: Mapped[str | None] = mapped_column(Text)
    latitud: Mapped[float | None] = mapped_column(Float)
    longitud: Mapped[float | None] = mapped_column(Float)
    estado: Mapped[str] = mapped_column(String(20), default="activa")  # activa | pausada | finalizada
    tipos_instalacion: Mapped[str | None] = mapped_column(Text)  # JSON array como texto para compatibilidad SQLite
    carpeta_servidor: Mapped[str | None] = mapped_column(Text)
    notas: Mapped[str | None] = mapped_column(Text)
    fecha_inicio: Mapped[date | None] = mapped_column(Date)
    fecha_fin_prevista: Mapped[date | None] = mapped_column(Date)
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
