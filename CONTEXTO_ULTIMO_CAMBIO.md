# 🧠 Registro de Última Gran Modernización - 28 de Marzo de 2026

## 🛠️ Estado actual de la arquitectura y rendimiento

Hoy se ha completado un ciclo de modernización crítica que resuelve los 3 cuellos de botella más importantes detectados en la auditoría de rendimiento y seguridad.

### ✅ Cambios implementados (Fases 1, 2 y 3)

1. **Seguridad Nativa de API Keys (Keychain)**
   - Se eliminó el rastro de OpenAI y Gemini API Keys de `UserDefaults` (texto plano).
   - Ahora se guardan en el **Keychain de macOS** bajo el `Bundle Identifier` (`kSecAttrService`).
   - Se implementó un sistema de **migración automática**: al abrir la app, las llaves viejas se mueven a la bóveda segura y se borra el rastro inseguro.

2. **Modernización de Red (Async/Await)**
   - Se erradicó el uso del framework `Combine` para las llamadas de IA.
   - Los servicios `OpenAIService` y `GeminiService` ahora son 100% nativos de Swift Concurrency (`async/await`), lo que reduce el uso de CPU y simplifica el flujo de errores.

3. **Buscador masivo en Hilo Secundario (Background Threading)**
   - El motor de búsqueda avanzado (Fuzzy, scoring, boosts) se movió de la UI a un hilo de fondo (`Task.detached`).
   - Se implementó un sistema de **cancelación proactiva**: si el usuario escribe rápido, las tareas de búsqueda anteriores se cancelan para no saturar la CPU.
   - Esto elimina por completo los "tirones" (beachballs) al navegar o filtrar miles de prompts.

4. **Optimización Inteligente de Imágenes (Smart Downsampling)**
   - **Pegado Instantáneo (Cmd+V)**: Ya no se bloquea la interfaz al pegar capturas Retina. El sistema ahora lee bytes directos del `NSPasteboard` y delega la compresión al fondo.
   - **Downsampling**: Redimensión automática a un máximo de **1200px** y compresión JPEG al 82% (calidad pro, peso mínimo < 300KB).
   - **Formatos**: Soporte universal (HEIC, WebP, PNG, RAW) con conversión inteligente según si hay transparencia o no.

5. **Correcciones Estructurales**
   - Se repararon los errores de llaves `{}` en `NewPromptView.swift` tras la refactorización masiva.
   - Se restauró la estabilidad de `SecondaryEditorCard` y el envío de prompts a la IA.

## 📁 Archivos más relevantes tocados

- `Promtier/Services/PreferencesManager.swift` (Enlace a Keychain)
- `Promtier/Services/PromptService.swift` (Buscador asíncrono)
- `Promtier/Services/OpenAIService.swift` (Migración a async/await)
- `Promtier/Services/GeminiService.swift` (Migración a async/await)
- `Promtier/Views/NewPromptView.swift` (Optimización de Cmd+V y correcciones)
- `Promtier/Services/ImageOptimizer.swift` (Lógicas de downsampling)

## 🧩 Especificaciones del Motor de Imágenes

- **Input**: PNG, JPEG, TIFF, BMP, HEIC, WebP, RAW.
- **Output**: PNG (si hay alpha) / JPEG .jpg (si es opaco).
- **Límites**: 1200px lado largo, 82% calidad, Thumbnails de 480px.
- **Background**: Procesamiento 100% fuera del Main Thread.

## ⚠️ Próximo paso recomendado (Fase 4)

**Desarticular el "God View" (`NewPromptView.swift`):**
El archivo sigue teniendo >3,300 líneas. Aunque es estable y rápido, su mantenimiento es difícil. El siguiente paso lógico es extraer componentes como `SecondaryEditorCard` o la barra de herramientas a archivos independientes para facilitar futuras mejoras.

---
*Actualizado para consolidar la Fase de Rendimiento y Seguridad (28/03/2026).*
