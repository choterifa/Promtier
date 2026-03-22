# 🧠 Registro de Último Cambio - 21 de Marzo de 2026

## 🛠️ OmniSearch (Spotlight Style) - Rediseño y Mejoras Críticas de UX

Se ha rediseñado el buscador global (OmniSearch) para ofrecer una experiencia nativa idéntica a Spotlight de macOS.

### ✅ Cambios Implementados

1.  **⚙️ Arquitectura de Foco y Panel:**
    *   **Cambio:** Se eliminó el flag `.nonactivatingPanel` del `OmniSearchPanel`.
    *   **Razón:** macOS bloqueaba las interacciones del ratón y el foco del teclado en sub-vistas (como el `TextField`) en paneles no activables. Ahora el panel es una ventana de utilidad estándar que acepta clics y foco correctamente.
    *   **Mejora:** Ahora se puede hacer clic en los resultados de búsqueda con el ratón sin que la ventana pierda el foco erráticamente.

2.  **⌨️ Navegación por Teclado Robusta:**
    *   **Cambio:** Se movió el monitor de eventos `NSEvent` de la vista (`OmniSearchView`) al gestor (`OmniSearchManager`).
    *   **Razón:** SwiftUI a veces consumía las flechas Arriba/Abajo dentro del campo de texto. El monitor global en el Manager intercepta estas teclas antes que el sistema de foco de SwiftUI, garantizando que la navegación por la lista siempre funcione.
    *   **Notificaciones:** Se implementó un sistema de notificaciones (`OmniSearchMove`) para comunicar el Manager con la Vista de forma desacoplada y persistente.

3.  **🔄 Restauración de Contexto (Focus Return):**
    *   **Cambio:** El `OmniSearchManager` ahora captura la `previousApp` (`NSRunningApplication`) justo antes de mostrarse.
    *   **Acción:** Al ocultar el buscador (Esc o Copiar), se llama a `previousApp.activate(options: .activateIgnoringOtherApps)`.
    *   **Resultado:** El foco vuelve automáticamente a la app donde el usuario estaba trabajando (Chrome, Slack, etc.), eliminando la necesidad de un clic manual tras copiar un prompt.

4.  **⚡ Algoritmo de Búsqueda Pesada:**
    *   **Cambio:** Se implementó una lógica de puntuación (`scoredPrompts`) en lugar de un simple `.contains`.
    *   **Pesos:** El Título tiene peso 100, la Descripción 40 y el Contenido 20. Se añade un bonus por coincidencia de prefijo (comienzo de palabra) y reciencia de uso.

### 🏗️ Notas Técnicas para el Futuro
*   Si el teclado deja de responder, verificar que `manager.isVisible` sea true en el monitor de `NSEvent` de `OmniSearchManager`.
*   Las filas de la lista (`OmniSearchRow`) se marcaron como `.focusable(false)` para que las flechas no intenten mover el foco azul de SwiftUI entre botones, sino que cambien el `selectedIndex` del buscador.

---
*Cambio realizado por el Agente de Air CLI.*
