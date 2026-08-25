# Hub Projects IA — Gentle AI para consultoría

Generador de proyectos hijos que extiende los conceptos y políticas de **Gentle AI** a consultoría, arquitectura, documentación, research, assessments, reuniones y entregables.

Gentle AI sigue siendo la autoridad de orquestación, delegación, skills y memoria. El hub agrega perfiles, estructura y workflows de dominio sin copiar su configuración administrada.

## Perfiles

| Perfil | Uso | Gentle AI |
|---|---|---|
| **ConsultingAI** | Default: consultoría + Consulting-Driven Delivery (CDD) | Requerido |
| **Full** | Alias retrocompatible de ConsultingAI | Requerido |
| **GentleAi** | Proyecto de desarrollo con skeleton mínimo | Requerido |
| **Consulting** | Fallback de consultoría sin CDD/Engram | No requerido |

Detalle: [docs/STACK-PROFILES.md](docs/STACK-PROFILES.md).

## Política de instalación

1. Detectar todos los ejecutables `gentle-ai`; si hay más de uno, detenerse y mostrar las rutas.
2. Si existe configuración global para Cursor, reutilizarla automáticamente.
3. Con global existente, **no mostrar ni permitir** instalación workspace.
4. Sólo si no existe global, preguntar: Global (recomendado), Proyecto o Cancelar.
5. Si falta el CLI, preguntar si se instala el canal estable con Go; ConsultingAI también permite elegir el fallback Consulting.
6. Engram lo administra Gentle AI. El generador nunca lo agrega al MCP local.
7. Si detecta global + workspace o Engram duplicado, diagnostica y se detiene; no borra ni reescribe archivos administrados.

La documentación oficial confirma que el alcance default es global, que `--scope=workspace` escribe archivos del agente en el proyecto y que las integraciones global-only siguen siendo globales: [Gentle AI README](https://github.com/Gentleman-Programming/gentle-ai), [usage](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/usage.md), [agents](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/agents.md).

## Uso

```powershell
Set-Location "ruta\a\hub-projects-ia\scripts"

# Diagnóstico read-only
.\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

# Default recomendado
.\New-HubProject.ps1 `
  -StackProfile ConsultingAI `
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"

# Consultoría sin Gentle AI
.\New-HubProject.ps1 `
  -StackProfile Consulting `
  -ClientDisplayName "ACME" -ClientSlug "acme" `
  -InitiativeDisplayName "Assessment" -InitiativeId "A01"

# Desarrollo
.\New-HubProject.ps1 -StackProfile GentleAi -ProjectName "mi-app"
```

Para automatización puede fijarse `-GentleAiScope Auto|Global|Workspace|Existing`. `Workspace` falla si ya existe global.

## Proyecto generado

- `PROJECT-CONTEXT.md`: entrada de contexto.
- `.cursorignore`: excluye fuentes pesadas de indexado automático.
- `context-budget.mdc` y `/start-task`: un objetivo/dominio y hasta dos archivos iniciales.
- `.cursor/mcp.json`: sólo MCP del proyecto (Draw.io, Backlog, Archi); nunca Engram.
- `.cdd/changes/`: artefactos CDD completos y versionables.
- Engram: decisiones, hallazgos, estado, resúmenes y punteros.

Sólo `consulting-copilot.mdc` y `context-budget.mdc` son always-on. Las reglas de transcripts, entregables, diagramas, onboarding y CDD se cargan por ámbito o demanda.

## Diagnóstico de proyectos existentes

```powershell
.\Test-GentleAiProject.ps1 -TargetPath "D:\clientes\iplan"
```

Es read-only. Informa duplicación global/workspace, MCP Engram local, skills que sombrean globales y reglas always-on excesivas. No migra automáticamente.

Guía: [docs/MIGRATION-GENTLE-AI.md](docs/MIGRATION-GENTLE-AI.md). Resumen de esta actualización: [docs/CHANGES-2026-08-25.md](docs/CHANGES-2026-08-25.md).

## Pruebas

```powershell
.\tests\Run-Tests.ps1
```

Requiere Pester. Cubre resolución de alcance, duplicados, perfiles, MCP local, always-on, skills y modelos.

## Hub y proyectos hijos

El template vive en `skeleton/` y `overlays/`. Los proyectos viven en `projects/`, quedan ignorados por Git en el padre y reciben su propio `git init`. Para trabajar, abrir siempre el hijo como workspace raíz.

Flujo: [HUB-WORKFLOW.md](HUB-WORKFLOW.md). MCP opcionales: [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md).
