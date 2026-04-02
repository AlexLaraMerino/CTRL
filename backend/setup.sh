#!/bin/bash
# ============================================================
#  CTRL API — Script de instalación para macOS (desarrollo)
# ============================================================

set -e

echo ""
echo "=== CTRL API — Instalación (desarrollo) ==="
echo ""

# 1. Crear entorno virtual
echo "[1/5] Creando entorno virtual..."
python3 -m venv venv
source venv/bin/activate

# 2. Instalar dependencias
echo "[2/5] Instalando dependencias..."
pip install -r requirements.txt
pip install aiosqlite greenlet

# 3. Configurar .env
if [ ! -f .env ]; then
    echo "[3/5] Creando .env desde plantilla..."
    cp .env.example .env
    echo ""
    echo "*** Edita .env si necesitas cambiar la configuración ***"
    echo ""
else
    echo "[3/5] .env ya existe, saltando..."
fi

# 4. Ejecutar migraciones
echo "[4/5] Ejecutando migraciones de base de datos..."
alembic upgrade head

# 5. Verificar
echo "[5/5] Verificando arranque..."
python3 -c "from app.main import app; print('OK: La API se importa correctamente')"

echo ""
echo "=== Instalación completada ==="
echo ""
echo "Para arrancar el servidor:"
echo "  source venv/bin/activate"
echo "  uvicorn app.main:app --reload"
echo ""
echo "Swagger disponible en: http://localhost:8000/docs"
echo ""
