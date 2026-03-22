# 🚀 Promtier - Gestor de Prompts para macOS

Promtier es un gestor de prompts moderno, minimalista y potente diseñado específicamente para macOS. Permite organizar, editar y utilizar tus prompts de IA con una experiencia de usuario fluida y nativa.

## ✨ Funciones Principales

### 🔍 Navegación y Organización
- **OmniSearch (Spotlight Style)**: 
    - **Atajo Maestro**: `Cmd + Shift + Space` para abrir un buscador global tipo Spotlight.
    - **Navegación Fluida**: Control total mediante flechas (`↑ / ↓`), `Enter` para copiar y `Esc` para salir.
    - **Foco Inteligente**: Al cerrar el buscador, el foco vuelve automáticamente a la aplicación donde estabas trabajando (ej. Chrome, Slack).
    - **Búsqueda Pesada**: Algoritmo que prioriza títulos sobre contenido y descripciones.
- **Búsqueda Inteligente**: Algoritmo híbrido (Fuzzy + Phrasal + Weighted) que prioriza títulos y uso frecuente en la ventana principal.
- **Categorías por Defecto (Rediseñadas)**:
    - **Code**: Icono terminal, color verde.
    - **Writing**: Icono lápiz, color azul.
    - **Image Generation**: Icono destellos, color púrpura.
    - **Marketing**: Icono megáfono, color naranja.
    - **Productivity**: Icono lista, color rosa.
    - **Automation**: Icono rayo, color amarillo.
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
    - **Verde Tenue**: Lista de Alternatives.
- **Jerarquía Visual**: Foco absoluto en el prompt principal con una sección dedicada de "Opciones Avanzadas" para contenido secundario.
- **Múltiples Alternativas**: Soporte para hasta **10 prompts alternativos** con gestión dinámica (añadir/eliminar).
- **Acciones Rápidas (Alternatives)**:
    - **Swap**: Intercambia el contenido de una alternativa con el principal instantáneamente.
    - **Remove**: Elimina alternativas de forma individual con animación.
    - **Branching**: Crea un nuevo prompt desde el contenido de una alternativa (con notificación visual y navegación directa).
    - **Diff View**: Vista modal para comparar visualmente diferencias entre el principal y la primera alternativa.
- **Copia Mágica (Atajos Globales)**: Registro de combinaciones de teclas por prompt (Framework Carbon) para copiar sin abrir la app.
- **Shortcuts Maestros**: 
    - **Edición**: `Cmd+S` para guardar, `Cmd+⇧+Z` para Modo Zen.
    - **Enfoque**: `⌥N` para Negative, `⌥A` para Alternative, `⌥V` para Variables.
    - **Navegación**: `↑ / ↓` para mover selección, `Cmd+B` para Sidebar.
- **Undo Safe**: Limpieza de historial de deshecho en ediciones automáticas para evitar crashes.
- **Resaltado de Sintaxis**: Bracket matching (naranja) y variables (azul) con feedback visual de pareja.

### 👁️ Vista Previa (Quick Look)
- **Drag Inteligente**: La ventana se mantiene abierta si el arrastre es hacia la sidebar (categorización), pero se cierra automáticamente al iniciar un arrastre (Drag) hacia otra app externa.
- **Visualizador Full-Screen**: Animaciones de zoom fluidas y soporte para gestos de trackpad corregidos.
- **Transitoriedad Reparada**: El popover recupera su capacidad de cierre por clic externo tras usar el visor de imágenes.

### 🛠️ Utilidades y UX
- **Dimensiones Pro**: Ancho predeterminado de **740px** y alto de **530px**.
- **Respuesta Háptica Fuerte**: El trackpad emite clics físicos potentes al redimensionar la ventana para sentir cada 10px.
- **Exportado Moderno**: Formato `.md` (Markdown) por defecto con títulos estructurados.
- **Botón Copiar**: Rediseñado para estar siempre visible a la derecha de cada card.
- **Ghost Tips**: Sistema de consejos flotantes que enseñan los atajos de teclado dinámicamente.

## 💎 Funciones Premium
- **Variables Dinámicas (Rellenar Variables)**:
    - **Formulario Inteligente**: Generación automática de campos para `{{variable}}`.
    - **Sintaxis de Listas**: Crea selectores con `{{Título: Opción 1, Opción 2}}` usando comas.
    - **Atajos de Teclado**: Copia instantánea del resultado final con `Cmd + C` o `Cmd + Enter`.
    - **Auto-Enfoque**: La vista se desplaza automáticamente para centrar el campo que estás escribiendo.
    - **Validación Estricta**: Obliga a rellenar todos los campos antes de permitir la copia.
- **Snippets Ilimitados**: Biblioteca completa de textos reutilizables (Atajo `/`).
- **Efectos Visuales**: Sistema de partículas y animaciones fluidas al guardar o copiar.
- **Historial Extendido**: Hasta 20 versiones guardadas por cada prompt.

---
*Última actualización: 19 de Marzo de 2026*
