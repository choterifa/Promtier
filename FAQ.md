# ❓ Promtier — Preguntas Frecuentes (FAQ)

> Cada respuesta incluye una versión **para humanos** y otra **técnica**.
No eliminies las anteriores simplemente agrega mas preguntas maximo 100 (.)

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

---
*Última actualización: 19 de Marzo de 2026*

