# CTRL

Aplicación de gestión de obras y operarios — iPad + servidor privado.

## Arquitectura

```
CTRL/
  backend/           ← API REST (Python · FastAPI)
    app/
      models/        ← ORM SQLAlchemy (obras, operarios, asignaciones, planos, historial)
      routers/       ← Endpoints REST
      schemas/       ← Validación Pydantic
      services/      ← Lógica de negocio
      utils/         ← JWT, autenticación
    tests/           ← Tests de integración
    alembic/         ← Migraciones de BD
  ios/               ← App iPad (SwiftUI) — pendiente
```

## Backend — Arranque rápido

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Migración inicial
alembic upgrade head

# Arrancar servidor
uvicorn app.main:app --reload
```

La API queda disponible en `http://localhost:8000` con Swagger en `/docs`.

### Credenciales de desarrollo

| Usuario    | Contraseña |
|------------|------------|
| gerente    | ctrl2026   |
| encargado  | ctrl2026   |

### Tests

```bash
cd backend
source venv/bin/activate
pytest tests/ -v
```

## Estado del proyecto

| Fase | Descripción | Estado |
|------|-------------|--------|
| 1 — Núcleo backend | Modelos, auth JWT, CRUD, historial | Completada |
| 2 — Mapa iOS | MapKit, chinchetas, barra superior | Pendiente |
| 3 — Asignaciones iOS | Calendario, drag-and-drop, copiar día | Pendiente |
| 4 — Planos | PDF + PencilKit, versionado | Pendiente |
| 5 — Detalle y pulido | Vistas completas, historial, rutas | Pendiente |
| 6 — Producción | Tests, HTTPS, despliegue Windows | Pendiente |

## Tecnología

- **Backend**: Python 3.11+ · FastAPI · SQLAlchemy · PostgreSQL/SQLite
- **App iOS**: SwiftUI · MapKit · PDFKit · PencilKit (pendiente)
- **Autenticación**: JWT
- **Despliegue**: Windows Server (producción) · macOS (desarrollo)
