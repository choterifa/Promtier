# 📌 Resumen de Cambios Importantes (Promtier)

## 🚀 Nuevas Funcionalidades
1. **Operaciones en Lote (Batch Mode)**:
   - Selección múltiple de prompts en la lista principal.
   - Barra de herramientas flotante con acciones rápidas: Mover a carpeta y Papelera.
   - Contador visual de items seleccionados.

2. **Rellenar Variables (Formulario Pro)**:
   - **Atajos**: Añadido `Cmd + C` para copiar el prompt final procesado instantáneamente.
   - **Auto-Scroll**: La vista centra automáticamente el campo en foco (Enter/Tab).
   - **Validación Estricta**: Todos los campos son obligatorios antes de poder copiar.
   - **Sintaxis Simplificada**: Selectores con comas `{{Label: Opción 1, Opción 2}}`.
   - **Mejora Visual**: Ventana más grande y altura dinámica (85-90% de la app).

3. **Ghost Tips (Consejos Inteligentes)**:
   - Pantalla completa y centrado inferior para mejor visibilidad.
   - Duración de 6.5 segundos.
   - Orden secuencial (bucle completo de tips).
   - Detección de Batch Mode para evitar solapamientos.

4. **Drag & Drop**:
   - Resaltado de bordes azules en categorías al arrastrar.
   - Reparado el cursor "+" (badge) para mayor claridad al mover prompts.
   - Solucionado conflicto de UTI que impedía arrastrar a apps externas.

## 🛠️ Correcciones Técnicas
- **Swift 6 Concurrency**: Corregido el error de captura de `NSTextStorage` en hilos secundarios.
- **SF Symbols**: Sustitución de iconos no compatibles para soportar más versiones de macOS.
- **Detección de Teclas Globales**: Refinada la lógica de Esc/Enter para no interferir con el visor de imágenes.

## 📂 Organización de Git
- **Ramas Limpias**: Consolidado todo el trabajo en `main` y `nueva`.
- **Eliminación de ramas antiguas**: Se borraron `diseño` y `fleet-local-history` para mantener un historial ordenado.
- **Estado Actual**: Trabajando directamente sobre la rama `nueva` (mismo contenido que `main`).
