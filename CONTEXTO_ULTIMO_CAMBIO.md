# 🧭 Contexto / Último Cambio (Handoff)

*Fecha: 19 de Marzo de 2026*

## ✅ Lo último implementado

### 1) Categorías y Organización Base
- **Nuevas Categorías por Defecto**: Rediseño total de las categorías iniciales: **Code, Writing, Image Generation, Marketing, Productivity, Automation**. 
- **SF Symbols e Iconos**: Cada categoría tiene ahora un icono y color único (ej: Terminal para Code, Megáfono para Marketing).
- **Sembrado (Seeding) V22**: Incremento de versión para forzar la creación de estas nuevas categorías en instalaciones existentes.

### 2) Interacción y Atajos de Teclado (Maestría)
- **Drag & Drop Inteligente**: Se ha mejorado el `onDrag` en `PromptCard` para permitir la **categorización interna**. Ahora la ventana solo se cierra si el arrastre sale fuera de los límites del popover (delay de 150ms de validación).
- **Shortcuts Globales y Locales**:
    - **Guardar**: `Cmd + S` ahora guarda el prompt activamente.
    - **Modo Zen**: `Cmd + ⇧ + Z` para alternar el editor a pantalla completa.
    - **Copia Final**: `Cmd + Enter` (además de `Cmd + C`) para copiar el resultado tras rellenar variables.
    - **Navegación**: Consolidación de tips de flechas (`↑ / ↓`) en un solo Ghost Tip.

### 3) UX y Sistema
- **Ghost Tips**: Actualización masiva de los consejos flotantes para enseñar todos los atajos de teclado disponibles.
- **Localización**: Actualización completa de `Localizable.strings` (EN/ES) con las nuevas categorías y descripciones de atajos.
- **Estabilidad**: Se corrigieron referencias a categorías obsoletas en el generador de prompts de ejemplo.

## 🧪 Próximos pasos sugeridos
- **CloudKit Dashboard**: Verificación visual de la sincronización entre dispositivos.
- **Quick Action Bar**: Barra de herramientas flotante al seleccionar texto en el editor.
- **Auto-Sync Icons**: Sincronizar el icono del prompt con el de su categoría automáticamente si no tiene uno personalizado.
