from fastapi import APIRouter, HTTPException, status

from app.schemas.auth import LoginRequest, TokenResponse
from app.utils.jwt import create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])

# Usuarios hardcoded para fase inicial. En producción se leerán de BD.
USERS = {
    "gerente": "ctrl2026",
    "encargado": "ctrl2026",
}


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest) -> TokenResponse:
    """Autentica un usuario y devuelve un JWT."""
    if request.username not in USERS or USERS[request.username] != request.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
        )
    token = create_access_token(data={"sub": request.username})
    return TokenResponse(access_token=token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: LoginRequest) -> TokenResponse:
    """Renueva el token (mismo flujo que login en fase inicial)."""
    return await login(request)
