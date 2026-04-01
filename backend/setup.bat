@echo off
REM ============================================================
REM  CTRL API — Script de instalación para Windows Server
REM  Requisitos: Python 3.11+ y PostgreSQL instalados y en PATH
REM ============================================================

echo.
echo === CTRL API — Instalación ===
echo.

REM 1. Crear entorno virtual
echo [1/5] Creando entorno virtual...
python -m venv venv
call venv\Scripts\activate.bat

REM 2. Instalar dependencias
echo [2/5] Instalando dependencias...
pip install -r requirements.txt
pip install asyncpg

REM 3. Configurar .env
if not exist .env (
    echo [3/5] Creando .env desde plantilla...
    copy .env.example .env
    echo.
    echo *** IMPORTANTE: Edita .env con los valores de tu entorno ***
    echo     - DATABASE_URL: cadena de conexión PostgreSQL
    echo     - SECRET_KEY: clave secreta larga y aleatoria
    echo     - CTRL_DATA_ROOT: ruta a la carpeta de datos
    echo.
    pause
) else (
    echo [3/5] .env ya existe, saltando...
)

REM 4. Ejecutar migraciones
echo [4/5] Ejecutando migraciones de base de datos...
alembic upgrade head

REM 5. Verificar
echo [5/5] Verificando arranque...
python -c "from app.main import app; print('OK: La API se importa correctamente')"

echo.
echo === Instalación completada ===
echo.
echo Para arrancar el servidor manualmente:
echo   venv\Scripts\activate.bat
echo   uvicorn app.main:app --host 0.0.0.0 --port 8000
echo.
echo Para registrar como servicio de Windows con NSSM:
echo   nssm install CTRL-API "%CD%\venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000
echo   nssm start CTRL-API
echo.
pause
