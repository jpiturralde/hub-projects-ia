# Diagramas de arquitectura (canónico)

Carpeta **solo para arquitectura interna canónica**: ArchiMate, C4, PlantUML y Draw.io de trabajo. Los borradores y entregables al cliente viven en [`docs/draft/`](../draft/) y [`docs/deliverables/`](../deliverables/).

## Estructura sugerida

```
docs/diagrams/
├── drawio/           # Diagramas Draw.io (C4, flujos)
├── puml/             # PlantUML fuente
├── {{ARCHIMATE_EXPORT_FILENAME}}   # Export ArchiMate (versionado en git)
├── {{ARCHIMATE_VIEWS_FILENAME}}    # Whiteboard complementario Draw.io
└── README.md
```

## Fuentes de verdad

| Información | Archivo / herramienta |
|-------------|------------------------|
| Modelo AS-IS ArchiMate | **Archi** + `{{ARCHIMATE_EXPORT_FILENAME}}` |
| Arquitectura narrativa | `ARCHITECTURE.md` |
| Gaps y preguntas | [`docs/architecture-gaps-and-questions.md`](../architecture-gaps-and-questions.md) |

`{{ARCHIMATE_VIEWS_FILENAME}}` es **complementario**; la fuente de verdad del modelo es Archi + el XML exportado.
