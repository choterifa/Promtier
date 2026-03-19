# 🧭 Contexto / Último Cambio (Handoff)

*Fecha: 18 de Marzo de 2026*

## ✅ Lo último implementado

### 1) Mejoras en el Editor y Campos Avanzados
- **Dimensiones:** Ancho por defecto ajustado a **710px**.
- **Alternative Prompt Actions:** Se añadieron botones con nombres en la barra de acciones:
  - **Swap:** Intercambia contenido principal y alternativo.
  - **Merge:** Anexa el alternativo al principal con un separador `---`.
  - **Branching:** Crea un nuevo prompt basado en el contenido alternativo (con notificación visual).
  - **Diff View:** Nueva vista en paralelo para comparar diferencias entre el Main Content y el Alternative Prompt.
- **Shortcuts de Teclado:** 
  - `⌥N` para enfocar Negative Prompt.
  - `⌥A` para enfocar Alternative Prompt.
- **Undo Safe:** Se corrigió un crash de `EXC_BAD_ACCESS` al usar Cmd+Z tras operaciones automáticas, limpiando el `undoManager` durante la sincronización.

### 2) Atajos Globales por Prompt (Copia Mágica)
- Cada prompt puede tener un **atajo personalizado** registrado vía framework Carbon.
- Funciona con la app minimizada o cerrada (copia directa al portapapeles).
- Si el prompt tiene variables `{{...}}`, la app se abre automáticamente para pedirlas.
- Persistencia completa en Core Data (`customShortcut`).

### 3) Interfaz y UX
- **Drag & Drop:** El popover se cierra automáticamente al iniciar un arrastre hacia afuera para no obstruir el destino.
- **Premium Upsell:** La pestaña de Snippets ahora muestra un efecto de desenfoque (blur) con un botón de desbloqueo si no es Premium.
- **Exportado:** Ahora exporta a archivos `.md` (Markdown) por defecto con formato de título.
- **Botón Copiar:** Siempre visible a la derecha en cada card de la lista para acceso rápido.

## 🧪 Próximos pasos sugeridos
- **IA Refiner:** Botón para "Mejorar prompt" usando Apple Intelligence directamente.
- **Smart Folders:** Carpetas automáticas basadas en etiquetas o frecuencia de uso.
- **Dashboard de Uso:** Ver estadísticas visuales de productividad.
- **Sincronización:** Indicador de estado de CloudKit en la barra superior.
