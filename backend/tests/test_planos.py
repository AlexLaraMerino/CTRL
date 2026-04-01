import io
from pathlib import Path
from unittest.mock import patch

import pytest
from httpx import AsyncClient


async def _create_obra(client: AsyncClient, auth: dict) -> str:
    r = await client.post("/obras", json={"nombre": "Obra Planos"}, headers=auth)
    return r.json()["id"]


@pytest.mark.asyncio
async def test_list_planos_empty(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    r = await client.get(f"/obras/{obra_id}/planos", headers=auth_header)
    assert r.status_code == 200
    assert r.json() == []


@pytest.mark.asyncio
async def test_upload_and_list_plano(client: AsyncClient, auth_header: dict, tmp_path: Path):
    obra_id = await _create_obra(client, auth_header)

    # Parchear CTRL_DATA_ROOT al directorio temporal
    with patch("app.routers.planos.settings") as mock_settings:
        mock_settings.ctrl_data_root = tmp_path
        r = await client.post(
            f"/obras/{obra_id}/planos",
            files={"file": ("test.pdf", b"%PDF-1.4 fake content", "application/pdf")},
            headers=auth_header,
        )
    assert r.status_code == 201
    plano = r.json()
    assert plano["nombre"] == "test.pdf"
    assert plano["version"] == 1

    r = await client.get(f"/obras/{obra_id}/planos", headers=auth_header)
    assert len(r.json()) == 1


@pytest.mark.asyncio
async def test_upload_anotacion(client: AsyncClient, auth_header: dict, tmp_path: Path):
    obra_id = await _create_obra(client, auth_header)

    with patch("app.routers.planos.settings") as mock_settings:
        mock_settings.ctrl_data_root = tmp_path
        # Subir original
        r = await client.post(
            f"/obras/{obra_id}/planos",
            files={"file": ("plano1.pdf", b"%PDF-1.4 original", "application/pdf")},
            headers=auth_header,
        )
        plano_id = r.json()["id"]

        # Subir anotación
        r = await client.post(
            f"/planos/{plano_id}/anotacion",
            files={"file": ("plano1_anotado.pdf", b"%PDF-1.4 anotado", "application/pdf")},
            headers=auth_header,
        )
    assert r.status_code == 200
    assert r.json()["version"] == 2
    assert r.json()["anotado_por"] == "gerente"


@pytest.mark.asyncio
async def test_plano_not_found(client: AsyncClient, auth_header: dict):
    r = await client.get("/planos/nonexistent", headers=auth_header)
    assert r.status_code == 404
