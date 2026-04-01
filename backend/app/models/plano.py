from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, gen_uuid


class Plano(TimestampMixin, Base):
    __tablename__ = "planos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    obra_id: Mapped[str] = mapped_column(String(36), ForeignKey("obras.id"), nullable=False)
    nombre: Mapped[str] = mapped_column(Text, nullable=False)
    ruta_original: Mapped[str] = mapped_column(Text, nullable=False)
    ruta_anotada: Mapped[str | None] = mapped_column(Text)
    version: Mapped[int] = mapped_column(Integer, default=1)
    anotado_por: Mapped[str | None] = mapped_column(String(100))
    anotado_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
