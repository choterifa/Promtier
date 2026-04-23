# 🛡️ Auditoría de Seguridad y Arquitectura - Tareas Pendientes

Durante la revisión profunda de la aplicación, se resolvieron varios problemas críticos (como el almacenamiento en texto plano de claves API, el cual migramos exitosamente a Apple Keychain). Sin embargo, quedan algunas tareas técnicas pendientes para blindar la aplicación al 100%:

## 1. Fugas de Memoria (Retain Cycles) en Closures Asíncronos

- **Problema:** En muchos servicios (como `ClipboardService`, `FloatingOnboardingManager`, `FloatingZenManager`), se utilizan closures asíncronos y colas (`DispatchQueue.main.async`) capturando `self` de manera fuerte. Esto impide que la clase se libere en memoria.
- **Acción a tomar:** Revisar todos los callbacks y llamadas asíncronas y asegurarse de agregar `[weak self]` o `[unowned self]` donde sea necesario.

## 2. Validación y Sanitización de Entrada (Input Validation)

- **Problema:** En `ClipboardService` y al recibir datos del portapapeles, los textos se pasan directamente a los motores de IA o se guardan en la base de datos sin un proceso riguroso de sanitización. Un texto malicioso extremadamente largo o con caracteres de desbordamiento podría causar cierres por agotamiento de memoria (OOM).
- **Acción a tomar:** Establecer un límite máximo manejable (truncado) antes de procesar desde el portapapeles y verificar la codificación de caracteres.

## 3. Seguridad de Red (Certificate Pinning)

- **Problema:** Las peticiones HTTPS a OpenAI, Gemini y OpenRouter confían ciegamente en los certificados del sistema. En redes públicas comprometidas, la app es susceptible a ataques _Man-in-the-Middle (MitM)_ si un atacante logra instalar un certificado raíz en el Mac del usuario.
- **Acción a tomar:** Implementar validación estricta de certificados (Certificate Pinning) usando `URLSessionDelegate` para garantizar que la app solo hable con los servidores reales de los proveedores de IA.

## 4. Ausencia de Cifrado en Base de Datos (Core Data)

- **Problema:** El contenedor SQLite de CoreData que guarda todos los prompts (`Promtier.sqlite`) reposa sin cifrado a nivel de fila o base de datos.
- **Acción a tomar:** Habilitar `NSFileProtectionComplete` para la base de datos SQL o, si se requiere una protección más estricta, migrar la capa de Core Data a cifrado usando SQLCipher a través de herramientas de terceros, o aprovechar completamente FileVault de Apple.

---

**Progreso Actual:** El vector de ataque más crítico (robo de la API Key desde UserDefaults) ya fue mitigado en la fase anterior introduciendo `KeychainHelper` con la política `kSecAttrAccessibleAfterFirstUnlock`.

💡 Sugerencias de Rendimiento y Fluidez para "Add/Edit Prompt" (NewPromptView.swift)
Al ver el número de variables de @State que tiene, cuando escribes texto rápido en un prompt largo la vista puede volverse lenta (Frame Drops). Para lograr la máxima fluidez, recomiendo:

Aislar los TextEditors (State Hoisting):
Actualmente hay más de 30 variables @State combinadas (texto, variables, booleanos). Cada vez que pulsas una letra en el prompt, SwiftUI re-evalúa y recarga toda la pantalla (incluidas imágenes, barras superiores, menús inferiones, tags, redibujo del panel).
Solución: Encapsula el TextEditor principal y el TextField del título en sub-vistas (struct EditorPrincipal: View) que tengan un @Binding o su propio estado interno @State. SwiftUI solo redibujará el área del texto y no la ventana entera.
Debounce en búsqueda de variables y snippets:
Si la vista escucha cada tecla para buscar snippets (las variables en { } o tags), utiliza la librería Combine. No dispares un recálculo de la vista ni iteración en tu array de snippets por cada letra. Un debounce(for: 0.15, scheduler: DispatchQueue.main) al texto en un ObservableObject hará que la lista autocomplete con suma rapidez.
Downsample de Imágenes Puras showcaseImages: [Data]:
Veo que los attachments visuales se guardan como cadenas de bytes nativos (Data). SwiftUI y NSImage decodifican la imagen en cada paso de scroll o cambio de tab. Si un usuario arrastra una imagen de 10 MB, se volverá una pesadilla de memoria y lag.
Solución: Usa Downsampling para crear miniaturas de previsualización (thumbails) en tu vista. Almacena en memoria o pasa a la vista una versión renderizada reducida (NSImage de ~400x400) durante la edición y conserva los datos puros en el background solo para persistirlos cuando pulsen "Guardar".
VStack a LazyVStack en campos dinámicos:
Para las etiquetas (Tags) o la galería de imágenes adjuntas mostradas abajo en el editor. Renderizar todo el árbol visual al unísono puede costar memoria extra, un LazyVStack o LazyHGrid solo construirá las vistas de lo que aparece expuesto en la ventana en ese preciso instante.
Uso de .equatable() para Vistas inmutables:
Las barras fijas de herramientas como el footer o selectores secundarios, puedes envolverlas con .equatable() (conforming Equatable a los structs pequeños) si se alimentan de datos fijos. Disminuirás dramáticamente la carga de procesamiento del árbol de tu UI general en cada tecla escrita.
