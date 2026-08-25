# Engram Artifact Convention — CDD (Consulting-Driven Development)

ALL CDD artifacts persisted to Engram MUST follow:

```
title:     cdd/{change-name}/{artifact-type}
topic_key: cdd/{change-name}/{artifact-type}
type:      architecture
project:   {detected or current project name}
scope:     project
capture_prompt: false
```

### Artifact Types

| Artifact Type | Produced By | Description |
|---------------|-------------|-------------|
| `explore` | cdd-explore | Relevamiento de fuentes |
| `proposal` | cdd-propose | Propuesta de entregable |
| `spec` | cdd-spec | Criterios de aceptación del entregable |
| `design` | cdd-design | Estructura doc + mapa fuentes canónicas |
| `tasks` | cdd-tasks | Secciones / anexos / diagramas |
| `apply-progress` | cdd-apply | Progreso de redacción |
| `verify-report` | cdd-verify | Reporte QA pre-cliente |
| `archive-report` | cdd-archive | Cierre y sync canónicos |
| `state` | orchestrator | DAG state for recovery |

### Project Init

```
title:     cdd-init/{project}
topic_key: cdd-init/{project}
```

## Recovery Protocol

```
Step 1: mem_search(query: "cdd/{change-name}/{artifact-type}", project: "{project}") → ID
Step 2: mem_get_observation(id: {observation-id}) → complete content
```

## Language

CDD internal artifacts default to **neutral professional Spanish** unless the user requests otherwise. Client-facing deliverables follow `draft-client-deliverable`.
