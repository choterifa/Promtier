# Promtier - Gestor de Prompts de IA para macOS

Aplicación de menu bar para gestionar prompts de inteligencia artificial con búsqueda rápida, organización y copiado al portapapeles.

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

- ✅ **Menu Bar Application**: Se ejecuta en la barra de menú de macOS
- ✅ **Búsqueda Pro**: Algoritmo híbrido (Fuzzy + Phrasal + Weighted) con límite de 7 en recientes.
- ✅ **Copia Mágica**: Atajos de teclado globales personalizados por cada prompt (vía Carbon).
- ✅ **Variables de Plantilla**: Soporte para `{{variable}}` con formulario de relleno inteligente.
- ✅ **Editor Avanzado**: Resaltado de sintaxis, bracket matching, auto-indentación y Diff View en paralelo.
- ✅ **Campos Avanzados**: Soporte para Negative y Alternative prompts con acciones de Swap/Merge/Branching.
- ✅ **Sistema de Favoritos**: Marca prompts como favoritos y accede a los más usados.
- ✅ **Organización**: Nuevas categorías por defecto (**Code, Writing, Image Generation, Marketing, Productivity, Automation**) con iconos/colores y Papelera con retención de 7 días.
- ✅ **Resultados con Imágenes**: Hasta 3 imágenes por prompt (guardadas en disco y optimizadas).
- ✅ **Copiado al Portapapeles**: Un clic para copiar o usar atajos globales.
- ✅ **Feedback Premium**: Respuesta háptica fuerte en trackpad y efectos visuales de partículas.
- ✅ **Backup/Restore**: Exportar a .md (Markdown), JSON, ZIP y CSV.
- ✅ **Drag & Drop**: Soporte inteligente: se mantiene abierto para categorización interna y se cierra automáticamente al arrastrar hacia afuera.

## 🏗️ Arquitectura

### Models
- `Prompt`: Modelo principal de prompts
- `Folder`: Organización por carpetas
- `TemplateVariable`: Gestión de variables de plantilla

### Services
- `PromptService`: Gestión de prompts (CRUD, búsqueda, papelera, imágenes, backup)
- `ClipboardService`: Operaciones del portapapeles
- `MenuBarManager`: Control del menu bar y popover
- `PreferencesManager`: Gestión de preferencias

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
3. **Copiar prompt**: Click en cualquier prompt para copiarlo
4. **Crear nuevo**: Botón `+` para nuevos prompts

## 📝 Notas

- La aplicación está configurada como **menu bar application**
- No aparecerá en el Dock, solo en la barra de menú superior
- Los datos se guardan localmente con Core Data + archivos en `Application Support` (imágenes)
- La versión actual usa `PromptService` como servicio principal

## 🔄 Desarrollo Futuro

- Integración completa con Core Data
- Atajos de teclado globales
- Sincronización con iCloud
- Interfaz de preferencias completa
