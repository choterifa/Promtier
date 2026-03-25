# 🧠 Registro de Último Cambio - 25 de Marzo de 2026

## 🛠️ Estado actual del trabajo más reciente

Este es el último bloque fuerte de cambios implementado para que otro modelo o desarrollador pueda retomarlo sin perder contexto.

### ✅ Cambios implementados

1. **Editor híbrido nativo (principal cambio)**
   - El editor dejó de comportarse como campo plano “disfrazado”.
   - Ahora usa `NSTextView` con formato visual real (bold, italic, inline code, listas e indentación).
   - Aun así, el contenido se sigue serializando a Markdown canónico para guardar/copiar/exportar de forma estable.

2. **Barra flotante de formato corregida**
   - La toolbar contextual al seleccionar texto ahora ejecuta comandos reales sobre el editor activo.
   - Se introdujo un sistema de ruteo por `editorID` para evitar que varias instancias del editor se mezclen.

3. **Resaltado de variables estabilizado**
   - Se quitó el resaltado de línea completa porque generaba ruido y repintados innecesarios.
   - El resaltado de `{{variables}}`, listas y cadenas vinculadas se aplica por cambios de contenido.
   - El matching de brackets ahora se actualiza aparte, para reducir el tintineo visual.

4. **UX del modal/editor de prompts**
   - El editor vuelve a cerrarse normalmente al hacer clic fuera de la app.
   - Se mantiene la protección de borrador/autosave, así que no depende de “bloquear” el popover.

5. **Layout del header del editor**
   - El icono del prompt se redujo y se compactó el spacing.
   - Título y descripción quedaron más alineados y más fáciles de atacar con el mouse.

6. **Infra ya existente preservada**
   - Negative Prompt y Alternatives siguen funcionando dentro del mismo sistema.
   - El soporte previo de imágenes en disco, ZIP backup/import, prewarm y throttling no se tocó en esta pasada.

## 📁 Archivos más relevantes tocados

- `Promtier/Views/HighlightedEditor.swift`
- `Promtier/Services/MarkdownRTFConverter.swift`
- `Promtier/Views/EditorToolbar.swift`
- `Promtier/Views/PromtierEditorCommand.swift`
- `Promtier/Views/NewPromptView.swift`
- `Promtier/Views/ZenEditorView.swift`
- `Promtier/Services/MenuBarManager.swift`

## 🧩 Decisiones técnicas importantes

- **Formato de edición:** visual/enriquecido.
- **Formato de persistencia:** Markdown canónico.
- **Motivo:** da mejor UX en edición sin romper compatibilidad con copia/export/import ni con prompts existentes.

- **Cierre al perder foco:** ahora el popover vuelve a ser transitorio en edición normal.
- **Motivo:** era más molesto dejarlo fijo que proteger el borrador por fuerza.

- **Resaltado:** se separó el highlight completo del bracket matching.
- **Motivo:** bajar repintados y quitar el flicker de las llaves.

## ⚠️ Cosas a vigilar si algo falla

1. Si el editor deja de reflejar cambios:
   - revisar `lastSerializedMarkdown` y `loadMarkdownIfNeeded` en `HighlightedEditor.swift`.

2. Si el formato visual se ve bien pero se guarda raro:
   - revisar `MarkdownRTFConverter.parseMarkdown(...)`
   - revisar `MarkdownRTFConverter.generateMarkdown(...)`

3. Si una toolbar actúa sobre el editor incorrecto:
   - revisar `PromtierEditorCommand.swift`
   - confirmar que cada editor esté recibiendo su `editorID` correcto.

4. Si vuelve el flicker de variables:
   - revisar `scheduleHighlighting(...)`
   - revisar `applyFullDecorations(...)`
   - revisar `applyBracketHighlight(...)`

5. Si el editor vuelve a quedarse abierto al perder foco:
   - revisar `MenuBarManager.updatePopoverBehavior()`
   - revisar asignaciones a `MenuBarManager.shared.isModalActive`

## 🔜 Buen siguiente paso

Si se quiere seguir mejorando esta línea de trabajo, lo más valioso es:

1. copiar/exportar como **Markdown / texto limpio / rich text**
2. guardar thumbnails persistentes en Core Data
3. añadir presets de formato por tipo de prompt (code, image, writing, marketing)

---
*Actualizado para handoff por Codex CLI.*
