# ❓ Promtier — Preguntas Frecuentes (FAQ)

> Cada respuesta incluye una versión **para humanos** y otra **técnica**.

## 1) ¿Cuántas imágenes permite por prompt?
**Para humanos:** Hasta **3 imágenes** de resultados por prompt.  
**Técnico:** Se persisten 3 slots: `image1Path/image2Path/image3Path` + `thumb1/thumb2/thumb3` (Core Data) y los archivos viven en `Application Support/.../Images/<promptUUID>/`.

## 2) ¿Dónde guarda Promtier mis imágenes?
**Para humanos:** En tu Mac, dentro de la carpeta de datos de la app (no en la nube).  
**Técnico:** `~/Library/Application Support/<bundleId>/Images/<promptUUID>/showcase_<n>.jpg|png`.

## 3) ¿Las imágenes se comprimen/optimizan?
**Para humanos:** Sí: se guardan “más ligeras” para que la app vaya rápida.  
**Técnico:** Al guardar se redimensionan a ~**1200px** (lado mayor) y se exportan como **JPEG** (si no hay alpha) o **PNG** (si hay transparencias). Además se generan thumbnails (~**480px**) para UI.

## 4) ¿Qué formatos de exportación existen?
**Para humanos:**  
- **ZIP (recomendado):** Backup completo con imágenes.  
- **JSON:** Un solo archivo (puede pesar mucho).  
- **CSV:** Para Excel/Sheets (sin imágenes).  
**Técnico:** ZIP exporta `manifest.json` + `Images/`; JSON incluye imágenes en base64; CSV exporta texto/metadata.

## 5) ¿Puedo exportar e importar sin perder categorías, historial y favoritos?
**Para humanos:** Sí. El backup guarda tus carpetas/categorías, favoritos, uso y más.  
**Técnico:** Se exportan prompts + folders con campos como `deletedAt`, `useCount`, `lastUsedAt`, `versionHistory`, `tags`, `negativePrompt`, `alternativePrompt`, etc. (según el formato).

## 6) ¿Qué pasa si importo y ya tengo un prompt con el mismo ID?
**Para humanos:** Se omite para evitar duplicados y evitar sobrescrituras.  
**Técnico:** Import (ZIP/JSON) hace “skip” por `id` existente; no sobreescribe el registro ni sus imágenes.

## 7) ¿Cuánto espacio ocupa guardar muchos prompts con imágenes (ej. 1000)?
**Para humanos:** Depende de cuántas imágenes uses, pero suele estar entre **~0.3 GB y ~1.5 GB**.  
**Técnico (estimación):**
- 1 imagen/prompt: ~300–490 MB (full 250–400KB + thumb 40–90KB).
- 3 imágenes/prompt: ~0.9–1.5 GB (3000 imágenes).
- Peor caso (mucho PNG): puede subir a varios GB.

## 8) ¿Promtier sube mis datos a internet?
**Para humanos:** No, por defecto todo queda local en tu Mac.  
**Técnico:** Persistencia local (Core Data + Application Support). iCloud Sync depende de configuración/estado del proyecto.

## 9) ¿Cómo hago un backup “seguro” para moverlo a otra Mac?
**Para humanos:** Exporta en **ZIP** y guarda ese archivo donde quieras (USB, iCloud Drive, etc.).  
**Técnico:** ZIP contiene manifest + `Images/`. Si quieres privacidad extra, puedes cifrar el archivo con herramientas del sistema (ej. en un volumen cifrado).

## 10) ¿Cómo libero espacio si tengo demasiadas imágenes?
**Para humanos:** Borra prompts con imágenes o haz un reset total si quieres empezar limpio.  
**Técnico:** Las imágenes viven en `Application Support/.../Images/`. El “Reset All” borra también esa carpeta.

