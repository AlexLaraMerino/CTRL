import shutil
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.obra import Obra
from app.models.plano import Plano
from app.schemas.plano import PlanoResponse
from app.services.historial_service import register_event
from app.utils.auth import get_current_user

router = APIRouter(tags=["planos"])


def _to_response(p: Plano) -> PlanoResponse:
    return PlanoResponse.model_validate(p)


def _obra_dir(obra_id: str) -> Path:
    return settings.ctrl_data_root / "obras" / obra_id


@router.get("/obras/{obra_id}/planos", response_model=list[PlanoResponse])
async def list_planos(
    obra_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> list[PlanoResponse]:
    """Lista de planos de una obra."""
    stmt = select(Plano).where(Plano.obra_id == obra_id).order_by(Plano.created_at.desc())
    result = await db.execute(stmt)
    return [_to_response(p) for p in result.scalars().all()]


@router.post("/obras/{obra_id}/planos", response_model=PlanoResponse, status_code=status.HTTP_201_CREATED)
async def upload_plano(
    obra_id: str,
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> PlanoResponse:
    """Sube un nuevo PDF a una obra."""
    obra = await db.get(Obra, obra_id)
    if not obra:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Obra no encontrada")

    if file.content_type and file.content_type != "application/pdf":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Solo se aceptan ficheros PDF")

    # Guardar fichero en disco
    planos_dir = _obra_dir(obra_id) / "planos"
    planos_dir.mkdir(parents=True, exist_ok=True)

    filename = file.filename or "plano.pdf"
    dest = planos_dir / filename

    # Evitar sobreescritura
    counter = 1
    while dest.exists():
        stem = Path(filename).stem
        dest = planos_dir / f"{stem}_{counter}.pdf"
        counter += 1

    content = await file.read()
    dest.write_bytes(content)

    plano = Plano(
        obra_id=obra_id,
        nombre=filename,
        ruta_original=str(dest.relative_to(settings.ctrl_data_root)),
    )
    db.add(plano)
    await db.flush()

    await register_event(
        db,
        usuario=user,
        tipo_accion="plano",
        entidad_tipo="plano",
        entidad_id=plano.id,
        descripcion=f"Plano subido: {filename} a obra {obra.nombre}",
        datos_nuevos={"nombre": filename, "obra_id": obra_id},
    )
    await db.commit()
    await db.refresh(plano)
    return _to_response(plano)


@router.get("/planos/{plano_id}")
async def download_plano(
    plano_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> FileResponse:
    """Descarga el PDF original de un plano."""
    plano = await db.get(Plano, plano_id)
    if not plano:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano no encontrado")

    file_path = settings.ctrl_data_root / plano.ruta_original
    if not file_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fichero no encontrado en disco")

    return FileResponse(
        path=str(file_path),
        media_type="application/pdf",
        filename=plano.nombre,
    )


@router.get("/planos/{plano_id}/anotado")
async def download_plano_anotado(
    plano_id: str,
    db: AsyncSession = Depends(get_db),
    _user: str = Depends(get_current_user),
) -> FileResponse:
    """Descarga la última versión anotada de un plano."""
    plano = await db.get(Plano, plano_id)
    if not plano:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano no encontrado")
    if not plano.ruta_anotada:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No hay versión anotada")

    file_path = settings.ctrl_data_root / plano.ruta_anotada
    if not file_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fichero anotado no encontrado en disco")

    return FileResponse(
        path=str(file_path),
        media_type="application/pdf",
        filename=f"anotado_{plano.nombre}",
    )


@router.post("/planos/{plano_id}/anotacion", response_model=PlanoResponse)
async def upload_anotacion(
    plano_id: str,
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(get_current_user),
) -> PlanoResponse:
    """Guarda una versión anotada del plano. El original nunca se sobreescribe."""
    plano = await db.get(Plano, plano_id)
    if not plano:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano no encontrado")

    # Guardar en carpeta de anotados
    anotados_dir = _obra_dir(plano.obra_id) / "planos-anotados"
    anotados_dir.mkdir(parents=True, exist_ok=True)

    new_version = plano.version + 1
    stem = Path(plano.nombre).stem
    dest = anotados_dir / f"{stem}_v{new_version}.pdf"

    content = await file.read()
    dest.write_bytes(content)

    old_data = {
        "version": plano.version,
        "ruta_anotada": plano.ruta_anotada,
    }

    plano.version = new_version
    plano.ruta_anotada = str(dest.relative_to(settings.ctrl_data_root))
    plano.anotado_por = user
    plano.anotado_en = datetime.now(timezone.utc)

    await db.flush()
    await register_event(
        db,
        usuario=user,
        tipo_accion="plano",
        entidad_tipo="plano",
        entidad_id=plano.id,
        descripcion=f"Anotación guardada: {plano.nombre} v{new_version}",
        datos_anteriores=old_data,
        datos_nuevos={"version": new_version, "ruta_anotada": str(dest)},
    )
    await db.commit()
    await db.refresh(plano)
    return _to_response(plano)
