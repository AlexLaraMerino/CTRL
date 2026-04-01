import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_and_get_obra(client: AsyncClient, auth_header: dict):
    # Crear
    r = await client.post(
        "/obras",
        json={
            "nombre": "Obra Test",
            "direccion": "Calle Falsa 123, Madrid",
            "latitud": 40.4168,
            "longitud": -3.7038,
            "tipos_instalacion": ["fontanería", "gas"],
        },
        headers=auth_header,
    )
    assert r.status_code == 201
    obra = r.json()
    assert obra["nombre"] == "Obra Test"
    assert obra["tipos_instalacion"] == ["fontanería", "gas"]
    obra_id = obra["id"]

    # Obtener por ID
    r = await client.get(f"/obras/{obra_id}", headers=auth_header)
    assert r.status_code == 200
    assert r.json()["id"] == obra_id


@pytest.mark.asyncio
async def test_list_obras(client: AsyncClient, auth_header: dict):
    await client.post("/obras", json={"nombre": "Obra A"}, headers=auth_header)
    await client.post("/obras", json={"nombre": "Obra B"}, headers=auth_header)
    r = await client.get("/obras", headers=auth_header)
    assert r.status_code == 200
    assert len(r.json()) >= 2


@pytest.mark.asyncio
async def test_update_obra(client: AsyncClient, auth_header: dict):
    r = await client.post("/obras", json={"nombre": "Obra Original"}, headers=auth_header)
    obra_id = r.json()["id"]
    r = await client.patch(f"/obras/{obra_id}", json={"nombre": "Obra Modificada"}, headers=auth_header)
    assert r.status_code == 200
    assert r.json()["nombre"] == "Obra Modificada"


@pytest.mark.asyncio
async def test_list_obras_activas(client: AsyncClient, auth_header: dict):
    await client.post(
        "/obras",
        json={"nombre": "Obra Activa", "estado": "activa"},
        headers=auth_header,
    )
    r = await client.get("/obras/activas", headers=auth_header)
    assert r.status_code == 200
    assert any(o["nombre"] == "Obra Activa" for o in r.json())


@pytest.mark.asyncio
async def test_obra_not_found(client: AsyncClient, auth_header: dict):
    r = await client.get("/obras/nonexistent", headers=auth_header)
    assert r.status_code == 404
