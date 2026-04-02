# Distribución via TestFlight

## Requisitos

- Cuenta Apple Developer Program activa (ya disponible)
- Xcode con signing configurado para el equipo
- La app compilando sin errores

## Pasos

### 1. Configurar la versión

En `project.yml`, verificar:

```yaml
MARKETING_VERSION: "0.1.0"
CURRENT_PROJECT_VERSION: "1"
```

Incrementar `CURRENT_PROJECT_VERSION` con cada subida.

### 2. Configurar la URL de producción

En `Sources/Services/APIClient.swift`:

```swift
private var baseURL = "https://ctrl.tudominio.com"
```

### 3. Archivar

1. En Xcode, seleccionar destino **Any iOS Device (arm64)**
2. Menu: **Product > Archive**
3. Esperar a que compile y archive

### 4. Subir a App Store Connect

1. Se abre el Organizer con el archivo
2. Pulsar **Distribute App**
3. Seleccionar **TestFlight Internal Only**
4. Seguir el asistente (firma automática)
5. Esperar a que Apple procese la build (10-30 min)

### 5. Invitar testers

1. Ir a https://appstoreconnect.apple.com
2. Seleccionar la app CTRL
3. Pestaña TestFlight
4. Crear un grupo de testers internos
5. Añadir al gerente y encargado por email
6. Ellos recibirán invitación para instalar TestFlight y la app

### Actualizaciones

Para cada nueva versión:
1. Incrementar `CURRENT_PROJECT_VERSION`
2. Archivar y subir
3. Los testers reciben notificación automática de actualización
