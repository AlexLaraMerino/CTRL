# CTRLiPad

Base nativa iPad-first de CTRL.

## Stack

- SwiftUI
- MapKit
- Codable persistence to Application Support

## Generación del proyecto

Este entorno no trae `xcodegen` instalado, así que el repositorio deja preparado el spec del proyecto:

```bash
brew install xcodegen
cd /Users/alex/Desktop/AlmaTechnologies/CTRL/ipad/CTRLiPad
xcodegen generate
open CTRLiPad.xcodeproj
```

## Cómo verlo en el simulador o en iPad

1. Abre `CTRLiPad.xcodeproj` en Xcode.
2. Elige un simulador de iPad, por ejemplo `iPad Pro 13-inch`.
3. Pulsa `Run`.
4. Si quieres probarlo en un iPad real:
   - conecta el iPad al Mac
   - selecciona tu dispositivo en Xcode
   - configura un equipo de firma en el target
   - pulsa `Run`

## Qué deberías ver ahora

- login por PIN de 4 cifras
- opción para recordar usuario en este iPad
- mapa a pantalla completa
- barra superior ligera
- agenda a la izquierda
- operarios y obras a la derecha
- botón `Gestión` abajo a la derecha
- selección de operario desde panel
- colocación sobre mapa
- snap operativo a obra cercana
- feedback visual cuando una obra es la candidata al soltar

## Objetivo de esta base

- mantener el dominio diario simple
- centrar la app en el mapa
- permitir una reimplementación limpia de gestos iPad-first
- preparar la futura integración de documentos por obra
