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
- ✅ **Búsqueda Rápida**: Encuentra prompts instantáneamente
- ✅ **Variables de Plantilla**: Soporte para `{{variable}}`
- ✅ **Sistema de Favoritos**: Marca prompts como favoritos
- ✅ **Organización**: Etiquetas y carpetas
- ✅ **Copiado al Portapapeles**: Un clic para copiar
- ✅ **Notificaciones**: Feedback visual y sonoro
- ✅ **Datos de Ejemplo**: Prompts pre-cargados para demostración

## 🏗️ Arquitectura

### Models
- `Prompt`: Modelo principal de prompts
- `Folder`: Organización por carpetas
- `TemplateVariable`: Gestión de variables de plantilla

### Services
- `PromptServiceSimple`: Gestión de prompts (versión simplificada)
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
- Los datos se guardan localmente con Core Data
- La versión actual usa `PromptServiceSimple` para simplicidad

## 🔄 Desarrollo Futuro

- Integración completa con Core Data
- Atajos de teclado globales
- Sincronización con iCloud
- Importación/Exportación de datos
- Interfaz de preferencias completa
