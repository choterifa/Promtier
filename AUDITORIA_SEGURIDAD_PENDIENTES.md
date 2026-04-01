# 🛡️ Auditoría de Seguridad y Arquitectura - Tareas Pendientes

Durante la revisión profunda de la aplicación, se resolvieron varios problemas críticos (como el almacenamiento en texto plano de claves API, el cual migramos exitosamente a Apple Keychain). Sin embargo, quedan algunas tareas técnicas pendientes para blindar la aplicación al 100%:

## 1. Fugas de Memoria (Retain Cycles) en Closures Asíncronos
- **Problema:** En muchos servicios (como `ClipboardService`, `FloatingOnboardingManager`, `FloatingZenManager`), se utilizan closures asíncronos y colas (`DispatchQueue.main.async`) capturando `self` de manera fuerte. Esto impide que la clase se libere en memoria.
- **Acción a tomar:** Revisar todos los callbacks y llamadas asíncronas y asegurarse de agregar `[weak self]` o `[unowned self]` donde sea necesario.

## 2. Validación y Sanitización de Entrada (Input Validation)
- **Problema:** En `ClipboardService` y al recibir datos del portapapeles, los textos se pasan directamente a los motores de IA o se guardan en la base de datos sin un proceso riguroso de sanitización. Un texto malicioso extremadamente largo o con caracteres de desbordamiento podría causar cierres por agotamiento de memoria (OOM).
- **Acción a tomar:** Establecer un límite máximo manejable (truncado) antes de procesar desde el portapapeles y verificar la codificación de caracteres.

## 3. Seguridad de Red (Certificate Pinning)
- **Problema:** Las peticiones HTTPS a OpenAI, Gemini y OpenRouter confían ciegamente en los certificados del sistema. En redes públicas comprometidas, la app es susceptible a ataques *Man-in-the-Middle (MitM)* si un atacante logra instalar un certificado raíz en el Mac del usuario.
- **Acción a tomar:** Implementar validación estricta de certificados (Certificate Pinning) usando `URLSessionDelegate` para garantizar que la app solo hable con los servidores reales de los proveedores de IA.

## 4. Ausencia de Cifrado en Base de Datos (Core Data)
- **Problema:** El contenedor SQLite de CoreData que guarda todos los prompts (`Promtier.sqlite`) reposa sin cifrado a nivel de fila o base de datos.
- **Acción a tomar:** Habilitar `NSFileProtectionComplete` para la base de datos SQL o, si se requiere una protección más estricta, migrar la capa de Core Data a cifrado usando SQLCipher a través de herramientas de terceros, o aprovechar completamente FileVault de Apple.

---
**Progreso Actual:** El vector de ataque más crítico (robo de la API Key desde UserDefaults) ya fue mitigado en la fase anterior introduciendo `KeychainHelper` con la política `kSecAttrAccessibleAfterFirstUnlock`.
