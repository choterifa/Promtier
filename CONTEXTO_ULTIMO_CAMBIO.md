# 🧭 Contexto / Último Cambio (Handoff)

*Fecha: 18 de Marzo de 2026*

Este archivo existe para que, si algo falla o un modelo/agente retoma el proyecto, tenga un resumen claro de lo último implementado y dónde tocar.

## ✅ Lo último implementado (alto nivel)

### 1) Imágenes “escalables”: disco + paths (Core Data)
- Las imágenes de resultados (máx. **3 por prompt**) ya **no viven como blobs grandes** en Core Data.
- Se guardan como archivos optimizados en:
  - `~/Library/Application Support/<bundleId>/Images/<promptUUID>/showcase_<n>.jpg|png`
- En Core Data se persiste:
  - `image1Path/image2Path/image3Path` (String)
  - `thumb1/thumb2/thumb3` (Binary, external storage)
- Hay migración:
  - **Background** al iniciar la app.
  - **On-demand** si un prompt legacy aún tiene blobs y se intenta abrir el preview.

Piezas clave:
- `Promtier/Services/ImageStore.swift`
- `Promtier/Core/Promtier.xcdatamodeld/.../contents`
- `Promtier/Services/PromptService.swift` (migración + CRUD con guardado en disco)

### 2) Importación/Exportación completa (incluye imágenes)
- **JSON (portable):** ahora incluye imágenes como base64 para que sea 1 archivo auto-contenido.
- **ZIP (recomendado):** nuevo backup completo con:
  - `manifest.json` (metadata: prompts + carpetas)
  - `Images/` (archivos de imagen)
  - Al importar ZIP, la app copia `Images/` a su `Application Support` y regenera thumbnails.

Piezas clave:
- `Promtier/Services/ZipService.swift` (usa `/usr/bin/ditto`)
- `Promtier/Models/BackupArchive.swift`
- `Promtier/Services/PromptService.swift`:
  - `exportBackupZip(to:)`
  - `importBackupZip(from:)`
  - `exportAllPromptsAsJSON()` (incluye imágenes base64)
- UI:
  - `Promtier/Views/PreferencesView.swift` (Data tab agrega ZIP)
  - `Promtier/Views/SearchViewSimple.swift` (drag&drop acepta `.zip`)

### 3) Rendimiento: prewarm + throttle de decodificación
Objetivo: evitar “beachball” al abrir preview con imágenes (especialmente tras arrancar la app).
- **Throttle global**: limita decodificaciones concurrentes para no saturar I/O/CPU.
- **Prewarm**: al hover/selección en la lista, decodifica la primera imagen del prompt en cache (mismo `cacheKey` del preview).

Piezas clave:
- `Promtier/Services/ImageDecodeThrottler.swift`
- `Promtier/Views/DownsampledImageURLView.swift`
- `Promtier/Views/DownsampledImageView.swift`
- `Promtier/Views/FullScreenImageView.swift`
- `Promtier/Views/SearchViewSimple.swift` (`prewarmPreviewImages(for:)`)

## 🧪 Cómo validar rápido
- Exporta un ZIP desde Settings → Data → ZIP, y vuelve a importarlo (en una DB limpia si quieres).
- Abre preview con `Space` en prompts con imágenes y revisa que:
  - La lista no se “trabe” al scrollear.
  - El preview abre sin beachball y las imágenes aparecen rápido.

## ⚠️ Notas / pendientes conocidos
- Hay warnings de Swift 6 (actor isolation) en algunas áreas antiguas; no bloquean build en este momento.
- El import ZIP **no sobrescribe prompts existentes por ID** (los omite para evitar pérdida de datos).

