# 🚀 Promtier - Gestor de Prompts para macOS

Promtier es un gestor de prompts moderno, minimalista y potente diseñado específicamente para macOS. Permite organizar, editar y utilizar tus prompts de IA con una experiencia de usuario fluida y nativa.

## ✨ Funciones Principales

### 🔍 Navegación y Organización
- **Búsqueda Inteligente**: Filtrado instantáneo de prompts por título, contenido o categoría.
- **Categorías y Carpetas**: Organización visual con iconos y colores personalizados.
- **Descripciones Breves**: Campo opcional de 100 caracteres para resumir prompts.
    - **Auto-generación ✨**: Botón inteligente para extraer la descripción automáticamente del contenido.
- **Sidebar Colapsable**: Panel lateral para filtrar por categorías, favoritos, recientes o papelera (Cmd+B).
- **Favoritos**: Acceso rápido a tus prompts más utilizados con un sistema de estrellas.
- **Papelera con Expiración**: 
    - **Retención**: Los prompts se guardan por 7 días antes de borrarse permanentemente.
    - **Countdown Visual**: Indicador de tiempo restante con colores de urgencia (verde/naranja/rojo).

### 📝 Editor Avanzado (Estilo VS Code)
- **Bracket Matching Pro**:
    - **Identificación**: Coloreado naranja de `{}`, `[]` y `()`.
    - **Parejas coincidentes**: Al situar el cursor en un bracket, su pareja se resalta con fondo gris y subrayado.
- **Resaltado de Variables**: Las variables `{{variable}}` se iluminan automáticamente en azul.
- **Auto-indentación Inteligente**:
    - Mantiene el nivel de sangría al presionar Enter.
    - Soporta listas automáticas (`-`, `*`, `•`).
- **Snippets con Trigger `/`**: Menú emergente de inserción rápida al escribir una barra diagonal.
- **Editor Zen**: Modo de pantalla completa para concentrarse únicamente en la escritura.
- **Historial de Versiones (Premium)**: Recupera versiones anteriores de tus prompts si cometiste un error.

### 👁️ Vista Previa (Quick Look)
- **Preview Rápido**: Visualiza el contenido completo y las imágenes sin abrir el editor (Espacio).
- **Consistencia Visual**: El preview mantiene el mismo resaltado de sintaxis (variables y brackets) que el editor.
- **Barra de Color Adaptativa**: Línea superior de 3px que adopta el color de la categoría actual.
- **Galería de Resultados**: Scroll lateral para previsualizar hasta 3 imágenes de referencia en alta resolución.

### 🤖 Inteligencia Artificial
- **Apple Intelligence Integration**: Acceso directo a *Writing Tools* de macOS 15+ desde el editor.
- **Modo Toggle Inteligente**:
    - **Abrir**: Invocación inmediata del panel de herramientas.
    - **Cerrar**: Simulación de señal `ESC` para cerrar el panel de IA sin cerrar la ventana de la app.
- **Visualización**: El icono de IA cambia de color (Multicolor vs Azul) según el estado activo de la sesión de IA.

### 🛠️ Utilidades y UX
- **Ghost Tips (Consejos Animados)**: Sistema de descubrimiento de funciones mediante avisos flotantes sutiles.
    - **Frecuencia**: Aparición secuencial (en bucle) cada 25-45 segundos.
    - **Duración**: Se ocultan automáticamente tras 6.5 segundos.
    - **Ubicación**: Centrados en la parte inferior para evitar obstrucciones.
    - **Tips Implementados**: `Vista Previa`, `Copiar Rápido`, `Nuevo Prompt`, `Configuración`, `Ocultar Sidebar`, `Drag & Drop`, `Multi-selección`, `Papelera` y `Exportar`.
- **Haptic Feedback (Trackpad)**: Retroalimentación física real en MacBook y Magic Trackpad.
    - **Niveles**: `Suave` (clics), `Medio` (alineación), `Éxito` (doble pulso) y `Error` (triple impacto).
- **Operaciones en Lote (Batch Mode)**:
    - **Selección Múltiple**: Selecciona varios prompts a la vez en la lista principal.
    - **Acciones Masivas**: Botones flotantes para mover prompts a carpetas o eliminarlos en bloque.
    - **Contador Real**: Visualización de cuántos items tienes seleccionados.
- **Drag & Drop Avanzado**:
    - **Soporte Universal**: Arrastra prompts entre categorías o hacia aplicaciones externas (Slack, Notion, etc.).
    - **Feedback Visual**: Resaltado de bordes azules en categorías al pasar por encima y cursor "+" reactivado.
- **Pegado Instantáneo**: Tecnología de automatización para transferir el prompt directamente a la app de destino.
- **Global Shortcut**: Invoca Promtier desde cualquier lugar del sistema con un atajo personalizable.
- **Importar/Exportar**: Soporte para copias de seguridad en JSON y exportación a CSV o texto plano.

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
*Última actualización: 17 de Marzo de 2026*
