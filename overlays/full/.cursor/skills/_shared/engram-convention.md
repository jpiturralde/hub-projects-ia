# Convención Engram para CDD

Engram es memoria y localizador; el repositorio es el almacén del artefacto completo.

```text
title: cdd/{change}/{artifact}-summary
topic_key: cdd/{change}/{artifact}
type: architecture
project: {project}
capture_prompt: false
content:
  Estado: ...
  Resumen: ...
  Decisiones/hallazgos: ...
  Riesgos: ...
  Archivo: .cdd/changes/{change}/{artifact}.md
  Siguiente: ...
```

No guardar cuerpos completos, transcripciones, documentación del cliente ni contenido ya versionado. Para recuperar, usar `mem_search` y abrir el archivo indicado; llamar `mem_get_observation` sólo si el resumen devuelto no alcanza.

