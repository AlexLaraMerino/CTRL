from sqlalchemy import Boolean, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, gen_uuid


class Operario(TimestampMixin, Base):
    __tablename__ = "operarios"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    nombre: Mapped[str] = mapped_column(Text, nullable=False)
    telefono: Mapped[str | None] = mapped_column(String(30))
    especialidades: Mapped[str | None] = mapped_column(Text)  # JSON array como texto
    activo: Mapped[bool] = mapped_column(Boolean, default=True)
    notas: Mapped[str | None] = mapped_column(Text)
