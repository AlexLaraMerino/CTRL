import pytest
from httpx import AsyncClient


async def _create_obra(client: AsyncClient, auth: dict) -> str:
    r = await client.post("/obras", json={"nombre": "Obra Asig"}, headers=auth)
    return r.json()["id"]


async def _create_operario(client: AsyncClient, auth: dict, nombre: str = "Op Test") -> str:
    r = await client.post("/operarios", json={"nombre": nombre}, headers=auth)
    return r.json()["id"]


@pytest.mark.asyncio
async def test_create_asignacion(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    op_id = await _create_operario(client, auth_header)
    r = await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-01"},
        headers=auth_header,
    )
    assert r.status_code == 201
    assert r.json()["operario_id"] == op_id


@pytest.mark.asyncio
async def test_list_asignaciones_by_date(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    op_id = await _create_operario(client, auth_header)
    await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-01"},
        headers=auth_header,
    )
    r = await client.get("/asignaciones?fecha=2026-04-01", headers=auth_header)
    assert r.status_code == 200
    assert len(r.json()) >= 1


@pytest.mark.asyncio
async def test_delete_asignacion(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    op_id = await _create_operario(client, auth_header)
    r = await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-02"},
        headers=auth_header,
    )
    asig_id = r.json()["id"]
    r = await client.delete(f"/asignaciones/{asig_id}", headers=auth_header)
    assert r.status_code == 204


@pytest.mark.asyncio
async def test_copiar_dia(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    op_id = await _create_operario(client, auth_header)
    await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-06"},
        headers=auth_header,
    )
    r = await client.post(
        "/asignaciones/copiar-dia",
        json={"fecha_origen": "2026-04-06", "fecha_destino": "2026-04-07"},
        headers=auth_header,
    )
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["fecha"] == "2026-04-07"


@pytest.mark.asyncio
async def test_extender_semana(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    op_id = await _create_operario(client, auth_header)
    # Lunes 6 abril 2026
    await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-06"},
        headers=auth_header,
    )
    r = await client.post(
        "/asignaciones/extender-semana",
        json={"fecha_origen": "2026-04-06"},
        headers=auth_header,
    )
    assert r.status_code == 200
    # Lunes -> martes, miércoles, jueves, viernes = 4 días
    assert len(r.json()) == 4


@pytest.mark.asyncio
async def test_reassign_deactivates_previous(client: AsyncClient, auth_header: dict):
    obra_id = await _create_obra(client, auth_header)
    op_id = await _create_operario(client, auth_header)
    # Primera asignación
    await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-03"},
        headers=auth_header,
    )
    # Segunda asignación mismo operario misma fecha
    await client.post(
        "/asignaciones",
        json={"operario_id": op_id, "obra_id": obra_id, "fecha": "2026-04-03"},
        headers=auth_header,
    )
    # Solo debería haber 1 activa
    r = await client.get("/asignaciones?fecha=2026-04-03", headers=auth_header)
    activas = [a for a in r.json() if a["operario_id"] == op_id]
    assert len(activas) == 1
