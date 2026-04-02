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
echo [2/6] Instalando dependencias...
pip install -r requirements.txt

REM 3. Crear base de datos PostgreSQL
echo [3/6] Verificando PostgreSQL...
echo Si PostgreSQL esta instalado, crea la base de datos con:
echo   psql -U postgres -c "CREATE DATABASE ctrl_db;"
echo (Si ya existe, puedes ignorar este paso)
echo.

REM 4. Configurar .env
if not exist .env (
    echo [4/6] Creando .env desde plantilla...
    copy .env.example .env
    echo.
    echo *** IMPORTANTE: Edita .env con los valores de tu entorno ***
    echo     - DATABASE_URL: cadena de conexión PostgreSQL
    echo     - SECRET_KEY: clave secreta larga y aleatoria
    echo     - CTRL_DATA_ROOT: ruta a la carpeta de datos
    echo.
    pause
) else (
    echo [4/6] .env ya existe, saltando...
)

REM 5. Ejecutar migraciones
echo [5/6] Ejecutando migraciones de base de datos...
alembic upgrade head

REM 6. Verificar
echo [6/6] Verificando arranque...
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
