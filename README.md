# Promtier - Gestor de Prompts de IA para macOS

Aplicación nativa de menu bar para macOS enfocada en crear, editar, organizar y exportar prompts de IA con una UX rápida, visual y pensada para uso diario.

## 🚀 Ejecución

### Desde Línea de Comandos
```bash
# Compilar
xcodebuild -scheme Promtier -configuration Debug build

# Ejecutar
open "/Users/valencia/Library/Developer/Xcode/DerivedData/Promtier-gwtwqauqniqqumfryffqozcsjphv/Build/Products/Debug/Promtier.app"
```

### Desde Xcode
1. **Cmd+R** para compilar y ejecutar
2. La aplicación aparecerá en la **barra de menú** (no en el Dock)
3. Busca el icono de Promtier en la barra de menú superior

## 📋 Características

- ✅ **Menu Bar App**: Vive en la barra de menú, sin estorbar en el Dock.
- ✅ **Búsqueda Pro**: Algoritmo híbrido (fuzzy + phrasal + weighted) con recientes optimizados.
- ✅ **Atajos Globales por Prompt**: Cada prompt puede registrar su propio hotkey de copiado.
- ✅ **Editor Nativo Híbrido**: Basado en `NSTextView` con formato visual real, persistencia canónica en Markdown y comandos de formato (`Cmd+B`, `Cmd+I`, listas, indentación).
- ✅ **Variables Dinámicas**: Resaltado estable de `{{variable}}`, navegación rápida y compatibilidad con el sistema existente.
- ✅ **Campos Avanzados**: Prompt principal, Negative Prompt y hasta 10 Alternatives con Swap, Merge, Diff y Branch.
- ✅ **Barra Flotante de Formato**: Menú contextual al seleccionar texto con acciones reales del editor.
- ✅ **Resultados con Imágenes**: Hasta 3 imágenes por prompt, optimizadas, con thumbnails y preview full image.
- ✅ **Storage Escalable**: Imágenes en disco + datos en Core Data/JSON para no inflar memoria innecesariamente.
- ✅ **Export / Import Completo**: Markdown, JSON portable, CSV y ZIP completo con imágenes.
- ✅ **Draft Autosave**: El editor puede cerrarse al perder foco sin perder el progreso.
- ✅ **Drag & Drop Inteligente**: Reordenar imágenes y mover prompts entre categorías desde la lista.
- ✅ **Modo Sobrio**: Desactiva halo, brillos y degradados para una UI más limpia.


## 🏗️ Arquitectura

### Models
- `Prompt`: Modelo principal de prompts
- `Folder`: Organización por carpetas
- `TemplateVariable`: Gestión de variables de plantilla

### Services
- `PromptService`: Gestión de prompts (CRUD, búsqueda, papelera, imágenes, backup/import-export)
- `ClipboardService`: Operaciones del portapapeles
- `MenuBarManager`: Control del menu bar y popover
- `PreferencesManager`: Gestión de preferencias
- `MarkdownRTFConverter`: Conversión entre Markdown canónico y edición enriquecida

### Views
- `SearchViewSimple`: Vista principal de búsqueda
- `ContentView`: Contenedor minimal

### Core
- `DataController`: Persistencia con Core Data
- `Info.plist`: Configuración de aplicación de menu bar

## 🔧 Configuración

### Configuraciones Clave en Info.plist
```xml
<key>LSUIElement</key>
<true/>
```
Esto hace que la aplicación no aparezca en el Dock.

### Configuraciones en PromtierApp.swift
```swift
NSApp.setActivationPolicy(.accessory)
```
Política de activación para aplicaciones de menu bar.

## 🎯 Uso

1. **Iniciar la aplicación**: Se ejecuta automáticamente al iniciar
2. **Buscar prompts**: Click en el icono de menu bar
3. **Copiar prompt**: Click en cualquier prompt o usa su atajo personalizado
4. **Crear/editar**: Botón `+`, menú contextual o `Cmd + N`
5. **Vista previa**: `Espacio` sobre un prompt seleccionado
6. **Alternar Galería**: `Cmd + G`
7. **Ajustes**: `Cmd + ,`

## 📝 Notas

- La aplicación está configurada como **menu bar application**
- No aparecerá en el Dock, solo en la barra de menú superior
- Los datos se guardan localmente con Core Data + archivos en `Application Support` para imágenes
- El editor visual sigue guardando una representación estable y portable
- El popover vuelve a comportarse como ventana transitoria en edición normal

## 🔄 Desarrollo Futuro

- Thumbnails persistentes en Core Data
- Resaltado incremental (rango visible) para prompts enormes
- Copia/export dual: Markdown / texto limpio / rich text
- Sincronización con iCloud
- Interfaz de preferencias completa

---

## 🐞 Técnicas de Debugging y Diagnóstico Usadas

- **Búsqueda de Errores y Warnings:**
  - `xcodebuild -scheme Promtier -project Promtier.xcodeproj build -destination "platform=macOS" | grep -E "error:|warning:"`
  - `swiftc -typecheck archivo.swift ...` para validar sintaxis rápida de archivos individuales.
  - `grep -Rn "palabraClave" carpeta/` para buscar funciones, variables o patrones en todo el código.
  - `cat archivo.swift | sed -n '100,120p'` para inspeccionar rangos de líneas específicos.
- **Inspección de Estado y Lógica:**
  - Revisar propiedades computadas (`hasUnsavedChanges`, `isContentEmpty`) y su lógica para evitar falsos positivos.
  - Uso de `.onAppear`, `.onDisappear`, y `.onChange` para rastrear inicialización y side-effects.
- **Refactorización Segura:**
  - Siempre validar cambios con compilación (`Cmd+B` o `xcodebuild`).
  - Usar comentarios `// ...existing code...` al editar para claridad en PRs.

---

## 🛠️ Exportar tu App (.app) y Firmar para Distribución

### 1. Compilar Release

Desde Xcode:
- Selecciona el esquema `Promtier` y el destino `My Mac (Release)`.
- Menú **Product > Archive** (esto genera el .app listo para exportar).

Desde terminal:
```bash
xcodebuild -scheme Promtier -configuration Release build
```

### 2. Firmar la App (Code Signing)

- Ve a **Xcode > Settings > Accounts** y agrega tu Apple ID.
- En el proyecto, selecciona el target `Promtier` > pestaña **Signing & Capabilities**.
- Elige tu equipo (Team) y selecciona **Sign to Run Locally** o tu certificado de desarrollador.
- Para distribución pública, usa un certificado de "Developer ID Application" (recomendado para apps fuera del App Store).

### 3. Exportar el .app

- Tras archivar, abre el **Organizer** (Xcode > Window > Organizer).
- Selecciona tu build y haz clic en **Distribute App** > **Developer ID** > **Export**.
- Esto generará un `.app` firmado y listo para compartir o subir a notarización.

### 4. Notarización (opcional pero recomendado)

Para evitar advertencias de Gatekeeper en otros equipos:
- Sube tu .app a Apple para notarización:
```bash
xcrun notarytool submit "Promtier.app" --apple-id "tu@appleid.com" --team-id TU_TEAM_ID --password "app-specific-password" --wait
```
- Una vez aprobado, "staplea" la firma:
```bash
xcrun stapler staple "Promtier.app"
```

---

## 📦 Exportar como ZIP

```bash
cd ruta/al/build/Release
zip -r Promtier.zip Promtier.app
```

¡Listo! Ahora puedes compartir tu app con otros usuarios de macOS.
