# 🚨 RECORDATORIO PARA IA / AI REMINDER

## Sincronización de Atajos de Teclado / Keyboard Shortcut Synchronization

**TODOS** los atajos de teclado nuevos o modificados deben ser registrados **OBLIGATORIAMENTE** en los siguientes dos lugares para mantener la consistencia en la experiencia del usuario:

1.  **Ghost Tips**: La lista de consejos flotantes que aparecen ocasionalmente.
    *   **Archivo**: `Promtier/Views/SearchViewSimple.swift` (propiedad `ghostTips`).
2.  **Shortcuts Tab**: La lista oficial de atajos en la pestaña de Configuración.
    *   **Archivo**: `Promtier/Views/PreferencesView.swift` (struct `ShortcutsTab`).

---

**ALL** new or modified keyboard shortcuts **MUST** be registered in the following two locations to maintain user experience consistency:

1.  **Ghost Tips**: The floating tip system that appears occasionally.
    *   **File**: `Promtier/Views/SearchViewSimple.swift` (`ghostTips` property).
2.  **Shortcuts Tab**: The official shortcut list in the Settings tab.
    *   **File**: `Promtier/Views/PreferencesView.swift` (`ShortcutsTab` struct).
