# ❓ Promtier — Preguntas Frecuentes (FAQ)

> Cada respuesta incluye una versión **para humanos** y otra **técnica**.
No elimines las anteriores; simplemente agrega más preguntas, máximo 100.

## 1) ¿Qué es la "Copia Mágica" y cómo funciona?
**Para humanos:** Es la capacidad de copiar cualquier prompt usando un atajo de teclado global (ej. `Cmd+Opt+1`) sin necesidad de abrir la aplicación. Funciona incluso si Promtier está minimizado o cerrado.
**Técnico:** Implementado mediante el framework **Carbon**, registrando `EventHotKey` individuales por cada prompt. Al detectarse la pulsación, se dispara una notificación que indica al `PromptService` que copie el contenido al `NSPasteboard`.

## 2) ¿Por qué el editor tiene diferentes colores de fondo?
**Para humanos:** Para ayudarte a identificar rápidamente qué estás escribiendo. El **Azul** es para tu prompt principal, el **Rojo** para el prompt negativo (lo que quieres evitar) y el **Verde** para una versión alternativa.
**Técnico:** La UI utiliza un tinte de fondo del 5% de opacidad basado en el tipo de campo dentro de `NewPromptView`, facilitando la jerarquía visual en formularios complejos.

## 3) ¿Necesito permisos de Accesibilidad para usar Promtier?
**Para humanos:** **Solo si activas el "Pegado Automático" (Instant Paste).** Para el resto de funciones (copiar, buscar, atajos globales) no necesitas ningún permiso especial.
**Técnico:** El pegado automático requiere simular eventos de teclado del sistema (`CGEvent` para Cmd+V), lo cual macOS bloquea por seguridad a menos que el usuario conceda permisos en *Ajustes del Sistema > Privacidad y Seguridad > Accesibilidad*.

## 4) ¿Qué hacen los botones Swap, Merge y Branching?
**Para humanos:** Son herramientas de productividad para iterar prompts:
- **Swap:** Intercambia el contenido principal con el alternativo.
- **Merge:** Junta el alternativo al final del principal con una línea divisoria.
- **Branching:** Crea un prompt nuevo independiente a partir del texto alternativo.
**Técnico:** Operaciones de mutación de strings que incluyen la limpieza del `undoManager` del `NSTextView` nativo para evitar errores de desincronización de memoria (`EXC_BAD_ACCESS`).

## 5) ¿Puedo comparar dos versiones de un prompt?
**Para humanos:** Sí, usando el botón **Diff**. Abrirá una ventana comparativa para ver las diferencias entre el contenido principal y el alternativo lado a lado.
**Técnico:** Se invoca la vista `DiffView.swift` que presenta ambos textos en una estructura de columnas paralelas con tipografía monoespaciada.

## 6) ¿Cómo funciona la sección de "Recientes"?
**Para humanos:** Muestra tus **7 prompts más importantes** del momento: aquellos que usaste en las últimas 48 horas o tus favoritos de siempre si no has usado muchos últimamente.
**Técnico:** Filtro híbrido que combina `lastUsedAt > 48h` con el `top 10` por `useCount`, eliminando duplicados y aplicando un `prefix(7)`.

## 7) ¿Qué formatos de exportación soporta?
**Para humanos:** Por defecto exporta a **Markdown (.md)**, pero también permite **ZIP** (completo con imágenes), **JSON** (portable) y **CSV** (tablas).
**Técnico:** La función de exportación utiliza `UTType.plainText` y `UTType.json`, y ahora prioriza `.md` envolviendo el título en un encabezado H1 para compatibilidad inmediata.

## 8) ¿Por qué la ventana se cierra sola al arrastrar un prompt?
**Para humanos:** Para que no te estorbe. Si lo arrastras hacia afuera (a otra app), se cierra. Pero si lo arrastras a la izquierda (hacia tus categorías), se queda abierta para que puedas organizarlo fácilmente.
**Técnico:** Implementación de un delay de validación de 150ms en `onDrag` que comprueba si la posición del ratón está fuera de los límites del `NSPopover` antes de llamar a `close()`.

## 9) ¿Puedo usar el teclado para todo?
**Para humanos:** ¡Casi! Hemos añadido atajos para guardar (`Cmd+S`), navegar (`↑ / ↓`), cambiar al modo Zen (`Cmd+⇧+Z`) y copiar el resultado final con variables (`Cmd+Enter`).
**Técnico:** Monitores de eventos de teclado locales y globales (`addLocalMonitorForEvents`) que interceptan KeyCodes específicos como el 1 (S) o el 6 (Z).

## 10) ¿Puedo sentir cuándo la ventana cambia de tamaño?
**Para humanos:** Sí, si tienes una MacBook o Magic Trackpad sentirás un "clic" físico cada vez que la ventana crece o se encoge 10 píxeles en los ajustes.
**Técnico:** Integración de `NSHapticFeedbackManager` con el nivel `.strong` disparado por el `.onChange` de los sliders de dimensiones en `PreferencesView`.

## 11) ¿Cuál es el tamaño ideal de la ventana?
**Para humanos:** La app viene configurada a **740x530px**, un tamaño balanceado para ver el editor avanzado y la lista de prompts sin scroll innecesario.
**Técnico:** Dimensiones fijadas como constantes de inicialización en `PreferencesManager.swift`.

## 12) ¿Cómo desactivo los efectos vibrantes y degradados (Halo Effects)?
**Para humanos:** Si prefieres una interfaz más seria y minimalista, ve a **Ajustes** y desactiva la opción **"Efectos Halo"**. Esto neutralizará los fondos de colores, sombras vibrantes y degradados del editor, dejando una app oscura "sobria".
**Técnico:** El sistema utiliza una propiedad reactiva `isHaloEffectEnabled` en `PreferencesManager` que conmuta dinámicamente entre `currentCategoryColor` y colores neutros (azul desaturado/gris) en todas las capas de `background`, `shadow` y `stroke` de la aplicación.

## 13) ¿El editor ahora es de texto enriquecido o sigue siendo Markdown?
**Para humanos:** Es ambas cosas. Tú editas de forma visual y más cómoda, pero Promtier guarda el contenido en un formato estable para que copiar y exportar siga funcionando bien.
**Técnico:** La edición se hace con `NSTextView` + `NSAttributedString`, mientras que la persistencia sigue usando Markdown canónico mediante `MarkdownRTFConverter`.

## 14) ¿Por qué ya no se resalta toda la línea actual?
**Para humanos:** Porque terminaba distrayendo más de lo que ayudaba. Se dejó un editor más limpio y más estable visualmente.
**Técnico:** El highlight de línea completa provocaba repintados extra en `drawBackground(in:)` y empeoraba la percepción de flicker; fue eliminado para reducir trabajo de render.

## 15) ¿Puedo cerrar el editor haciendo clic fuera sin perder cambios?
**Para humanos:** Sí. Ahora se cierra normal, pero tus cambios siguen protegidos con borrador/autosave.
**Técnico:** El popover volvió a `transient` durante edición normal y el contenido se conserva vía `DraftService` + guardado incremental del estado de `NewPromptView`.

## 16) ¿Cuántas imágenes puedo guardar por prompt?
**Para humanos:** Hasta **3 imágenes por prompt** en la versión actual.
**Técnico:** La UI y el modelo actual limitan `showcaseImages` a 3 slots por prompt para controlar peso, decodificación y layout del preview.

## 17) ¿Las imágenes se comprimen?
**Para humanos:** Sí. Promtier las optimiza automáticamente para que ocupen menos espacio y carguen mejor.
**Técnico:** Las imágenes pasan por `ImageOptimizer` antes de guardarse; además se generan versiones más ligeras para preview/thumbnail según el flujo de importación/exportación.

## 18) ¿Dónde se guardan las imágenes?
**Para humanos:** Dentro de los datos locales de la app en tu Mac, no en una carpeta suelta del escritorio.
**Técnico:** Se guardan en `Application Support` bajo el bundle de la app, usando archivos en disco y no blobs gigantes en memoria para mejorar escalabilidad.

## 19) ¿Qué conviene más: exportar en JSON o en ZIP?
**Para humanos:** Si quieres algo simple y portátil, usa **JSON**. Si quieres un respaldo más grande y confiable con imágenes reales, usa **ZIP**.
**Técnico:** JSON embebe imágenes en base64 y puede crecer rápido; ZIP separa manifiesto + archivos, reduce sobrecarga y es mejor para librerías grandes.

## 20) ¿Puedo exportar todo sin perder categorías, textos, historial e imágenes?
**Para humanos:** Sí, esa es justo la idea del backup completo.
**Técnico:** El flujo de export/import completo contempla prompts, categorías, metadata, imágenes y estado relacionado; ZIP es la ruta más robusta para preservar assets sin inflación base64.

## 21) ¿Cuántos prompts soporta Promtier?
**Para humanos:** Para una biblioteca normal o grande va bien; cientos o miles son razonables si las imágenes se manejan optimizadas.
**Técnico:** El cuello de botella no suele ser el texto sino imágenes, thumbnails, decodificación y fetches completos; por eso se migró a almacenamiento en disco y prewarm controlado.

## 22) ¿Por qué a veces un prompt con imágenes tardaba en abrir?
**Para humanos:** Porque antes macOS tenía que decodificar demasiado de golpe al mostrar la vista previa.
**Técnico:** El costo venía de lectura + decodificación + render en el momento de abrir; se redujo con prewarm, throttling de decodificación y almacenamiento más ligero.

## 23) ¿Puedo seguir usando variables tipo `{{subject}}` con el editor visual?
**Para humanos:** Sí, siguen funcionando igual.
**Técnico:** Las variables no dependen del markdown enriquecido; se detectan por regex y se mantienen compatibles con el flujo de inserción, navegación y formulario final.

## 24) ¿Promtier guarda solo el prompt principal?
**Para humanos:** No. También puede guardar negative prompt, alternativas, imágenes, categoría, atajo, apps asociadas y más.
**Técnico:** El modelo `Prompt` ya contempla metadata extendida como `negativePrompt`, `alternatives`, `promptDescription`, `targetAppBundleIDs`, `customShortcut` e imágenes.

---
*Última actualización: 25 de Marzo de 2026*
