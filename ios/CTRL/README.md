# CTRL — App iOS

App nativa iPad-first para gestión de obras y operarios.

## Requisitos

- Xcode 15+
- iOS/iPadOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) para generar el proyecto

## Generación del proyecto

```bash
brew install xcodegen
cd ios/CTRL
xcodegen generate
open CTRL.xcodeproj
```

## Configuración del servidor

Por defecto la app apunta a `http://localhost:8000`. Para cambiar la URL del servidor, edita `APIClient.swift`:

```swift
private var baseURL = "http://TU_IP_SERVIDOR:8000"
```

En desarrollo local, asegúrate de que el backend está corriendo:

```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0
```

## Estructura

```
Sources/
  App/              ← Entry point
  Models/           ← Modelos Codable (espejo de la API)
  Services/         ← APIClient, AuthManager, DailyStateManager
  Views/
    Auth/           ← Login
    Common/         ← MainView, TopBar
    Map/            ← MapaView con MapKit
    Panels/         ← CalendarPanel, RightPanel (obras/operarios)
    Obras/          ← ObraDetailView
    Operarios/      ← OperarioDetailView
    Planos/         ← PlanoViewerView (PDFKit + PencilKit)
    Historial/      ← HistorialView
```

## Funcionalidades implementadas

- Login con JWT
- Mapa de España con chinchetas de obras (azul) y operarios (marrón/verde)
- Barra superior con navegación de fecha
- Panel izquierdo: calendario + acciones rápidas (copiar ayer, extender semana)
- Panel derecho: lista de obras y operarios con drag-to-assign
- Detalle de obra: datos, operarios del día, planos, historial
- Detalle de operario: datos, calendario semanal, historial
- Visor de planos PDF con anotaciones PencilKit
- Historial global con filtros por tipo
