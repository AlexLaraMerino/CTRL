# Despliegue en Windows Server

## Requisitos previos

- Windows Server 2019 o superior
- Python 3.11+ (instalar desde python.org, marcar "Add to PATH")
- PostgreSQL 15+ (instalar desde postgresql.org)
- Puerto 443 abierto en el firewall

## Paso 1: Instalar PostgreSQL

1. Descargar e instalar desde https://www.postgresql.org/download/windows/
2. Anotar la contraseña del usuario `postgres`
3. Abrir pgAdmin o usar psql para crear la base de datos:

```
psql -U postgres
CREATE DATABASE ctrl_db;
\q
```

## Paso 2: Instalar el backend

```batch
cd C:\ctrl\backend
setup.bat
```

Esto crea el entorno virtual, instala dependencias y ejecuta las migraciones.

Editar `.env` con los valores reales:

```
DATABASE_URL=postgresql://postgres:TU_PASSWORD@localhost/ctrl_db
SECRET_KEY=una-clave-secreta-larga-y-aleatoria-generada
CTRL_DATA_ROOT=C:\datos-ctrl
ALLOWED_ORIGINS=https://ctrl.tudominio.com
```

## Paso 3: Registrar como servicio Windows

Descargar NSSM desde https://nssm.cc/download

```batch
nssm install CTRL-API "C:\ctrl\backend\venv\Scripts\python.exe" -m uvicorn app.main:app --host 127.0.0.1 --port 8000
nssm set CTRL-API AppDirectory C:\ctrl\backend
nssm start CTRL-API
```

Verificar que funciona: `http://localhost:8000/health`

## Paso 4: Configurar HTTPS con Caddy

Caddy es la opción más sencilla. Gestiona certificados SSL automáticamente.

1. Descargar desde https://caddyserver.com/download (Windows amd64)
2. Copiar `caddy.exe` a `C:\caddy\`
3. Copiar `deploy/Caddyfile` a `C:\caddy\Caddyfile`
4. Editar el Caddyfile con tu dominio real
5. Registrar como servicio:

```batch
cd C:\caddy
caddy install
```

## Paso 5: Configurar la carpeta de datos

Crear la estructura:

```batch
mkdir C:\datos-ctrl\obras
mkdir C:\datos-ctrl\backups
```

## Paso 6: Configurar la app iOS

En `APIClient.swift`, cambiar la URL a:

```swift
private var baseURL = "https://ctrl.tudominio.com"
```

## Paso 7: Backups automáticos

Crear una tarea programada de Windows para backup diario de PostgreSQL:

```batch
pg_dump -U postgres ctrl_db > C:\datos-ctrl\backups\ctrl_%date:~-4%%date:~3,2%%date:~0,2%.sql
```

Programar en el Programador de Tareas de Windows para ejecutar diariamente.
