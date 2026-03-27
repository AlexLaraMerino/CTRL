# CTRL

CTRL pasa a una nueva etapa: base nativa iPad-first para priorizar una UX táctil fluida sobre el mapa.

## Dirección actual

- Plataforma principal: `iPad`
- Enfoque técnico: `SwiftUI + MapKit`
- Persistencia inicial: local, simple y robusta
- Dominio central: `DailyState` independiente por fecha

## Estado del repositorio

```text
CTRL/
  docs/
  frontend/        # base anterior Expo/React Native, mantenida como referencia
  ipad/
    CTRLiPad/
      project.yml
      README.md
      Sources/
```

## Nueva base nativa

La nueva app iPad vive en:

`/Users/alex/Desktop/AlmaTechnologies/CTRL/ipad/CTRLiPad`

Incluye:

- estructura de proyecto para generar con `XcodeGen`
- modelos nativos del dominio
- store local-first
- primera shell SwiftUI
- mapa base con `MapKit`
- paneles operativos para agenda, operarios y obras

## Nota sobre la base anterior

La carpeta `frontend/` no se elimina por ahora. Se conserva como referencia funcional del MVP anterior y como apoyo para portar decisiones de dominio.

## Siguiente foco

1. generar y abrir el proyecto iPad en Xcode
2. validar layout y persistencia local
3. rehacer la interacción de operarios sobre el mapa con gesto iPad-first
4. preparar más adelante la estrategia de PDF con `PDFKit + PencilKit`
