# QA Auto-Check - NewPrompt Editor

Fecha: 2026-04-19

## Resultado rapido

- Build: PASS
- Errores de compilacion: 0
- Cobertura automatica: validacion estatica de wiring y flujo en codigo

## Evidencia automatica (PASS)

### Flujo Base

- Version history solo en cambios core premium: PASS
  - Evidencia: appendVersionSnapshotIfNeeded y deteccion de coreChanges en save flow.

### Draft

- Carga de draft al abrir editor: PASS
  - Evidencia: setupOnAppear + DraftService.shared.loadDraft.
- Auto-guardado de draft por cambios: PASS
  - Evidencia: onChange(of: draftState) -> saveCurrentDraft.
- Limpieza de draft al guardar y al descartar: PASS
  - Evidencia: DraftService.shared.clearDraft en savePrompt(closeAfter: true) y discardChanges.

### Teclado

- Cmd+S: PASS
  - Evidencia: handleSaveShortcut.
- Cmd+C sin seleccion: PASS
  - Evidencia: handleCopyShortcut + isTextSelectedInEditor.
- Cmd+V imagen: PASS
  - Evidencia: handlePasteImageShortcut + appendOptimizedImageData.
- ESC (overlays/foco/cierre): PASS
  - Evidencia: handleEscapeShortcut.
- Option+N / Option+A / Option+V: PASS
  - Evidencia: handleQuickFocusShortcut.
- Flechas galeria + Space preview: PASS
  - Evidencia: handleImageGalleryArrowShortcut + handleSpacePreviewShortcut.

### Galeria e importacion

- Pipeline unificado con validaciones: PASS
  - Evidencia: PromptMediaImportPipeline en PromptImageShowcaseView y NewPromptView.
- Mensajes de error por slots/tipo/tamano: PASS
  - Evidencia: localizedMessage(for:) + showImageImportWarning.

### Overlays

- Toast transitorio: PASS
  - Evidencia: NewPromptBranchMessageOverlay + showTransientBranchMessage.
- Modal Magic encapsulado: PASS
  - Evidencia: NewPromptMagicOptionsOverlay.
- Overlays snippets/variables siguen conectados: PASS
  - Evidencia: snippetsOverlayLayer y variablesOverlayLayer.

## Pendiente (manual en UI)

- Abrir/cerrar editor nuevo y existente, incluyendo guardado sin cambios.
- Confirmar comportamiento visual (parpadeos/saltos).
- Validar interaccion real de teclado con foco en distintos controles.
- Confirmar drag and drop real de imagenes y preview fullscreen.
- Confirmar comportamiento premium/no premium en overlays.

## Notas

Este reporte no reemplaza pruebas manuales de UI; verifica wiring, reglas de flujo y compilacion.
