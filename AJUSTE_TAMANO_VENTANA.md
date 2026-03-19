# 📏 Ajuste de Tamaño de Ventana - Promtier

## ✅ **Cambio Realizado (Última Actualización)**

### 🎯 **Dimensiones Pro Establecidas:**
- **Ancho**: 740 píxeles
- **Alto**: 530 píxeles
- **Propósito**: Espacio optimizado para el nuevo editor avanzado con campos de Negative y Alternative prompt.

### 📋 **Archivos Modificados:**

#### 1. **PreferencesManager.swift**
```swift
// Inicialización por defecto
self.windowWidth = 740
self.windowHeight = 530
```

#### 2. **PreferencesView.swift**
```swift
// Botón Restablecer
preferences.windowWidth = 740
preferences.windowHeight = 530
```

---

## 🎨 **Evolución del Tamaño**

| Versión | Tamaño (W×H) | Motivo |
|-------|----------------|--------------|
| Legacy | 700×550px | Prototipo inicial |
| Compact | 500×400px | Minimalismo extremo |
| **Actual (Pro)** | **740×530px** | **Soporte para campos avanzados y acciones del editor** |

---

## 🚀 **Ventajas de las Nuevas Dimensiones**

- ✅ **Editor sin Scroll**: Permite ver el contenido principal y los chips avanzados simultáneamente.
- ✅ **Comparación Cómoda**: La nueva **Diff View** aprovecha el ancho adicional para mostrar textos en paralelo.
- ✅ **Identidad Visual**: Proporciones que se sienten nativas en macOS, similares a un panel de inspector profesional.
- ✅ **Respuesta Háptica**: Integración de clics físicos fuertes en el trackpad para guiar el redimensionado manual.

---

## 🔥 **Conclusión**

El tamaño de **740×530px** es ahora el estándar oficial de Promtier, garantizando que todas las herramientas avanzadas (Swap, Merge, Branching) sean accesibles sin comprometer la limpieza de la interfaz. 🚀✨
