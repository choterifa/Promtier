# 🧠 Registro de Modernización y Rendimiento - Marzo 31 de 2024

## 🛠️ Estado actual de la arquitectura y rendimiento

Hoy hemos completado un ciclo de **optimización crítica de recursos y refactorización UI**, resolviendo cuellos de botella severos, consumos excesivos de CPU/Batería y reduciendo el caos de re-renders de SwiftUI.

### ✅ Cambios implementados

1. **Eficiencia Energética y CPU (Zero-Waste CPU) 🔋**
   - **Gestor de Portapapeles (`ClipboardService`):** Se eliminó el `Timer` en bucle eterno a 1 segundo. Ahora escucha reactivamente notificaciones nativas (`NSApplication.willBecomeActiveNotification`) de macOS para evitar desgastar la batería en segundo plano (amigable con *App Nap*).
   - **Animaciones GPU vs CPU:** Eliminado el bloque `.onReceive` de 25 FPS de `PlaceholderSlotView`. La animación de `dashPhase` se delegó a `.animation(...)` para correr en la GPU nativa de Metal sin tocar la CPU principal.

2. **Supresión de Fallos de UI y Consola 🛑**
   - **Arreglo del Bug de ProgressView Matemática:** Los `ProgressView` de macOS colisionaban con `.fixedSize()` propiciando la advertencia *maximum length (16.086957) doesn't satisfy min <= max*. Múltiples redimensiones de UI fueron parcheadas a un limpio `.scaleEffect()`.
   - **Fix del Bucle de Cambios (Ver Undefined Behavior):** Reemplazo de lógica de vistas en `MenuBarManager.swift` (y creación de `PopoverContainerView`) para delegar el refresco del Locale a `@Environment` en vez de reinstanciar el host controller manualmente (esto provocaba `Publishing changes from within view updates is not allowed`).
   - Se arregló el auto-hide del `AccessibilityBanner` (5 segundos).

3. **Restricción y Blindaje de CoreData (Memoria RAM) 💾**
   - Implementadas configuraciones de `fetchBatchSize = 25` y `50` en `PromptEntity` y `FolderEntity`. Core Data ahora dosificará los picos de memoria bajo demanda para colecciones amplias en vez de cargar todas las filas de golpe.

4. **Desarticulación del God View y Modularización 🧩**
   - La colosal vista `NewPromptView.swift` bajó de casi **4,200 líneas a ~2,860 líneas**. Hemos extraído exitosamente diversas vistas.

## 📁 Archivos más relevantes tocados
- `CONTEXTO_ULTIMO_CAMBIO.md`
- `Promtier/Services/MenuBarManager.swift`
- `Promtier/Services/ClipboardService.swift`
- `Promtier/Views/PlaceholderSlotView.swift`
- `Promtier/Core/PromptEntity+Extensions.swift`
- `Promtier/Views/AccessibilityBanner.swift`

## ⚠️ Próximo paso (Continuación C)

**Continuar Despedazando el "God View" (`NewPromptView.swift`):**
A pesar del progreso, la vista `NewPromptView` interactúa con una gran maraña de variables `@State`. Al teclear texto, la app debe re-evaluar todo el struct principal y produce lag de tecleo y alto uso de la UI principal sobre CPU. Continuaremos extrayendo en Phase C las sub-vistas como `header()`, `bottomBar()`, `tagSection()`, etc para que aislemos los redibujos de la cadena SwiftUI.
