# 🧭 Contexto / Último Cambio (Handoff)

*Fecha: 18 de Marzo de 2026*

## ✅ Lo último implementado

### 1) Editor Avanzado y Código de Colores
- **Fondo de Editor**: Se aplicaron tintes sutiles (5% opacidad) para diferenciar áreas:
  - **Main Content**: Azul tenue.
  - **Negative Prompt**: Rojo tenue.
  - **Alternative Prompt**: Verde tenue.
- **Botones de Acción**: Añadidos nombres a los iconos para mayor claridad: `Swap`, `Merge`, `Branching` y `Diff`.
- **Diff View**: Implementada vista en paralelo para comparar versiones del prompt.

### 2) Estabilidad y Correcciones
- **Undo Safe**: Limpieza del `undoManager` al realizar cambios programáticos (Swap/Merge) para evitar crashes `EXC_BAD_ACCESS` al pulsar Cmd+Z.
- **Copia Mágica**: Registro global de atajos (vía Carbon) ahora persistente. El campo `customShortcut` se carga correctamente desde Core Data.
- **Fix Popover**: Reparado el bug de macOS que "congelaba" la ventana tras usar el visor de imágenes (ahora recupera el estado transitorio).

### 3) UX y Sistema
- **Dimensiones**: Estándar **740px x 530px**.
- **Haptic Strong**: Respuesta táctil profunda en los sliders de redimensionado.
- **Recientes (Top 7)**: Lógica refinada para mostrar solo los 7 prompts más frescos o frecuentes.
- **Exportación**: Cambio a formato **Markdown (.md)** por defecto.
- **Drag & Drop**: El popover se cierra automáticamente al iniciar un arrastre hacia aplicaciones externas.

## 🧪 Próximos pasos sugeridos
- **Apple Intelligence Integration**: Botón de "Pulido por IA" para mejorar la gramática del prompt.
- **Dynamic Variable Options**: Soporte para menús desplegables en variables `{{Label: Op1, Op2}}`.
- **CloudKit Dashboard**: Verificación visual de la sincronización entre dispositivos.
