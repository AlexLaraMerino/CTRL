from datetime import datetime, timezone

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, gen_uuid


class Historial(Base):
    __tablename__ = "historial"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    usuario: Mapped[str] = mapped_column(String(100), nullable=False)
    tipo_accion: Mapped[str] = mapped_column(String(50), nullable=False)  # asignacion | obra | operario | plano | config
    entidad_tipo: Mapped[str] = mapped_column(String(50), nullable=False)
    entidad_id: Mapped[str] = mapped_column(String(36), nullable=False)
    descripcion: Mapped[str] = mapped_column(Text, nullable=False)
    datos_anteriores: Mapped[str | None] = mapped_column(Text)  # JSON
    datos_nuevos: Mapped[str | None] = mapped_column(Text)  # JSON
