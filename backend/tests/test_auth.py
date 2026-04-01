import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    r = await client.post("/auth/login", json={"username": "gerente", "password": "ctrl2026"})
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_invalid_credentials(client: AsyncClient):
    r = await client.post("/auth/login", json={"username": "gerente", "password": "wrong"})
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_protected_endpoint_without_token(client: AsyncClient):
    r = await client.get("/obras")
    assert r.status_code in (401, 403)
