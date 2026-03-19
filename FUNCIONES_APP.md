# 🚀 Promtier - Gestor de Prompts para macOS

Promtier es un gestor de prompts moderno, minimalista y potente diseñado específicamente para macOS. Permite organizar, editar y utilizar tus prompts de IA con una experiencia de usuario fluida y nativa.

## ✨ Funciones Principales

### 🔍 Navegación y Organización
- **Búsqueda Inteligente**: Algoritmo híbrido (Fuzzy + Phrasal + Weighted) que prioriza títulos y uso frecuente.
- **Categorías y Carpetas**: Organización visual con iconos y colores personalizados.
- **Recientes (Top 7)**: Sección optimizada que muestra los usados en las últimas 48h combinados con los más exitosos históricamente (máx. 7).
- **Descripciones Breves**: Campo opcional con fondo azul tenue para identificar prompts rápidamente.
- **Sidebar Colapsable**: Panel lateral (Cmd+B) para filtrar por categorías, favoritos, recientes o papelera.
- **Papelera (Drag & Drop)**: 
    - **Interacción**: Soporta arrastrar prompts directamente para eliminarlos.
    - **Retención**: 7 días antes del borrado permanente.

### 📝 Editor Avanzado (Diseño Pro)
- **Código de Colores**: 
    - **Azul Tenue**: Contenido principal.
    - **Rojo Tenue**: Negative Prompt.
    - **Verde Tenue**: Alternative Prompt.
- **Acciones Rápidas (Alternative Prompt)**:
    - **Swap**: Intercambia Main ↔ Alternative instantáneamente.
    - **Merge**: Concatena el alternativo al final con separador `---`.
    - **Branching**: Crea un nuevo prompt desde el alternativo con un clic (con notificación de éxito).
    - **Diff View**: Vista modal para comparar visualmente diferencias entre el principal y el alternativo.
- **Copia Mágica (Atajos Globales)**: Registro de combinaciones de teclas por prompt (Framework Carbon) para copiar sin abrir la app.
- **Shortcuts de Enfoque**: `⌥N` para Negative, `⌥A` para Alternative.
- **Undo Safe**: Limpieza de historial de deshecho en ediciones automáticas para evitar crashes.
- **Resaltado de Sintaxis**: Bracket matching (naranja) y variables (azul) con feedback visual de pareja.

### 👁️ Vista Previa (Quick Look)
- **Cierre Inteligente**: La ventana se cierra automáticamente al iniciar un arrastre (Drag) hacia otra app.
- **Visualizador Full-Screen**: Animaciones de zoom fluidas y soporte para gestos de trackpad corregidos.
- **Transitoriedad Reparada**: El popover recupera su capacidad de cierre por clic externo tras usar el visor de imágenes.

### 🛠️ Utilidades y UX
- **Dimensiones Pro**: Ancho predeterminado de **740px** y alto de **530px**.
- **Respuesta Háptica Fuerte**: El trackpad emite clics físicos potentes al redimensionar la ventana para sentir cada 10px.
- **Exportado Moderno**: Formato `.md` (Markdown) por defecto con títulos estructurados.
- **Botón Copiar**: Rediseñado para estar siempre visible a la derecha de cada card.

## 💎 Funciones Premium
- **Variables Dinámicas (Rellenar Variables)**:
    - **Formulario Inteligente**: Generación automática de campos para `{{variable}}`.
    - **Sintaxis de Listas**: Crea selectores con `{{Título: Opción 1, Opción 2}}` usando comas.
    - **Atajos de Teclado**: Copia instantánea del resultado final con `Cmd + C`.
    - **Auto-Enfoque**: La vista se desplaza automáticamente para centrar el campo que estás escribiendo.
    - **Validación Estricta**: Obliga a rellenar todos los campos antes de permitir la copia.
- **Snippets Ilimitados**: Biblioteca completa de textos reutilizables.
- **Efectos Visuales**: Sistema de partículas y animaciones fluidas al guardar o copiar.
- **Historial Extendido**: Hasta 20 versiones guardadas por cada prompt.

---
*Última actualización: 18 de Marzo de 2026*
