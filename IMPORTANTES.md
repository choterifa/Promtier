# 📌 Resumen de Cambios Importantes (Promtier)

## 🚀 Nuevas Funcionalidades
0. **Dimensiones Dinámicas**:
   - Tamaño predeterminado ajustado a **740px x 530px**.
   - Respuesta háptica fuerte (Strong) en el redimensionado para una sensación mecánica.

1. **Editor Avanzado y Copia Mágica**:
   - **Copia Mágica**: Registro de atajos globales individuales por prompt (framework Carbon). Funciona con la app cerrada.
   - **Acciones Pro**: Botones integrados en el header del editor (Swap, Merge, Branching, Diff) con etiquetas claras.
   - **Branching Automático**: Navegación directa a la lista tras clonar un prompt para mejorar la agilidad.
   - **Color Coding**: Identificación visual inmediata de campos (Azul para principal, Rojo para negativo, Verde para alternativo).

2. **UX y Estabilidad**:
   - **Auto-Close Drag**: El popover se cierra al arrastrar un prompt hacia afuera para no obstruir el destino.
   - **Fix Transient State**: Reparado el bug de macOS que congelaba el popover tras cerrar un visor de imágenes.
   - **Markdown Export**: Exportado enriquecido a `.md` con metadatos estructurados.

## 🛠️ Correcciones Técnicas
- **Undo Safe Implementation**: Limpieza de `undoManager` en el `NSTextView` nativo al realizar cambios programáticos (Merge/Swap) para evitar crashes de memoria (`EXC_BAD_ACCESS`).
- **Core Data Custom Shortcut**: Mapeo completo del nuevo atributo `customShortcut` para persistencia y carga inicial.
- **Recent Category Logic**: Filtro optimizado para mostrar solo los 7 prompts más relevantes (usados en <48h o más frecuentes).

## 📂 Organización de Git
- **Ramas Limpias**: Consolidado todo el trabajo en `main` y `nueva`.
- **Eliminación de ramas antiguas**: Se borraron `diseño` y `fleet-local-history` para mantener un historial ordenado.
- **Estado Actual**: Trabajando directamente sobre la rama `nueva` (mismo contenido que `main`).
