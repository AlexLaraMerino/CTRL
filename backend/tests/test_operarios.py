import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_and_get_operario(client: AsyncClient, auth_header: dict):
    r = await client.post(
        "/operarios",
        json={
            "nombre": "Juan García",
            "telefono": "612345678",
            "especialidades": ["fontanería", "CPI"],
        },
        headers=auth_header,
    )
    assert r.status_code == 201
    op = r.json()
    assert op["nombre"] == "Juan García"
    assert op["especialidades"] == ["fontanería", "CPI"]

    r = await client.get(f"/operarios/{op['id']}", headers=auth_header)
    assert r.status_code == 200
    assert r.json()["nombre"] == "Juan García"


@pytest.mark.asyncio
async def test_list_operarios(client: AsyncClient, auth_header: dict):
    await client.post("/operarios", json={"nombre": "Op A"}, headers=auth_header)
    await client.post("/operarios", json={"nombre": "Op B"}, headers=auth_header)
    r = await client.get("/operarios", headers=auth_header)
    assert r.status_code == 200
    assert len(r.json()) >= 2


@pytest.mark.asyncio
async def test_update_operario(client: AsyncClient, auth_header: dict):
    r = await client.post("/operarios", json={"nombre": "Original"}, headers=auth_header)
    op_id = r.json()["id"]
    r = await client.patch(f"/operarios/{op_id}", json={"nombre": "Modificado"}, headers=auth_header)
    assert r.status_code == 200
    assert r.json()["nombre"] == "Modificado"


@pytest.mark.asyncio
async def test_operario_not_found(client: AsyncClient, auth_header: dict):
    r = await client.get("/operarios/nonexistent", headers=auth_header)
    assert r.status_code == 404
