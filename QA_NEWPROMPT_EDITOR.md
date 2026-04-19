# QA Manual - Editor NewPrompt

## Objetivo

Validar que el refactor de NewPromptView mantiene el comportamiento funcional y no reintroduce bloqueos o regresiones visuales.

## Precondiciones

- Build en verde.
- App abierta en modo crear y editar prompt.
- Premium activo y no activo (probar ambos cuando aplique).

## Checklist

### Flujo Base

- [ ] Abrir editor nuevo y cerrar sin cambios.
- [ ] Abrir editor de prompt existente y guardar sin cambios.
- [ ] Guardar cambios en titulo, contenido y descripcion.
- [ ] Verificar que version history se crea solo cuando cambia contenido core (premium).

### Draft

- [ ] Escribir en prompt nuevo y cerrar: se restaura draft correctamente.
- [ ] Guardar prompt: draft se limpia.
- [ ] Descartar cambios: draft no vuelve a aparecer.

### Teclado

- [ ] Cmd+S guarda (en modo normal y en zen).
- [ ] Cmd+C sin seleccion copia contenido completo.
- [ ] Cmd+V con imagen en portapapeles importa imagen.
- [ ] ESC cierra overlays; si no hay overlays, quita foco/cierra segun estado.
- [ ] Option+N enfoca negative prompt.
- [ ] Option+A enfoca alternativa.
- [ ] Option+V abre variables (o upsell en no premium).

### Galeria y Preview

- [ ] Flechas izq/der cambian seleccion de imagen cuando no hay foco de texto.
- [ ] Espacio abre/cierra preview fullscreen de la imagen seleccionada.
- [ ] Drag&drop reordena imagenes.
- [ ] Import por boton +, por drag&drop y por Cmd+V comparte validaciones.
- [ ] Mensajes de error aparecen para slots llenos o archivo invalido.

### Overlays

- [ ] Overlay de snippets abre/cierra y selecciona con teclado.
- [ ] Overlay de variables abre/cierra y selecciona con teclado.
- [ ] Modal de Magic abre/cierra, cambia target y ejecuta accion.
- [ ] Toast de branch/errores aparece y se oculta automaticamente.

### Regression visual

- [ ] Layout del header del editor conserva icono, favoritos y carpeta.
- [ ] Prompt Results mantiene tamano uniforme de slots y placeholders.
- [ ] No hay saltos visuales o parpadeos al abrir/cerrar overlays.

## Criterio de salida

- Cero errores de compilacion.
- Cero crashes.
- Cero regresiones funcionales en los casos del checklist.
