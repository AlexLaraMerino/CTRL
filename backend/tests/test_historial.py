import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_historial_records_obra_creation(client: AsyncClient, auth_header: dict):
    r = await client.post("/obras", json={"nombre": "Obra Historial"}, headers=auth_header)
    obra_id = r.json()["id"]

    r = await client.get(f"/historial/obra/{obra_id}", headers=auth_header)
    assert r.status_code == 200
    entries = r.json()
    assert len(entries) >= 1
    assert entries[0]["tipo_accion"] == "obra"


@pytest.mark.asyncio
async def test_historial_global(client: AsyncClient, auth_header: dict):
    await client.post("/obras", json={"nombre": "Obra H1"}, headers=auth_header)
    await client.post("/operarios", json={"nombre": "Op H1"}, headers=auth_header)
    r = await client.get("/historial", headers=auth_header)
    assert r.status_code == 200
    assert len(r.json()) >= 2


@pytest.mark.asyncio
async def test_historial_filter_by_tipo(client: AsyncClient, auth_header: dict):
    await client.post("/obras", json={"nombre": "Obra Filter"}, headers=auth_header)
    r = await client.get("/historial?tipo=obra", headers=auth_header)
    assert r.status_code == 200
    for entry in r.json():
        assert entry["tipo_accion"] == "obra"
