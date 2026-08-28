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

Motor único: **PowerShell 7** (`pwsh`) en Windows y Ubuntu/WSL. Catálogo de scripts: [scripts/README.md](scripts/README.md).

```powershell
# Windows
Set-Location "C:\ruta\hub-projects-ia\scripts"
pwsh -NoProfile -File .\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

pwsh -NoProfile -File .\New-HubProject.ps1 `
  -StackProfile ConsultingAI `
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"
```

```bash
# Ubuntu / WSL (launcher)
cd /home/usuario/work/hub-projects-ia
./scripts/hub doctor -StackProfile ConsultingAI
./scripts/hub new -StackProfile ConsultingAI \
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" \
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"

# o invocación directa
cd /home/usuario/work/hub-projects-ia/scripts
pwsh -NoProfile -File ./Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

pwsh -NoProfile -File ./New-HubProject.ps1 \
  -StackProfile Consulting \
  -ClientDisplayName "ACME" -ClientSlug "acme" \
  -InitiativeDisplayName "Assessment" -InitiativeId "A01"

pwsh -NoProfile -File ./New-HubProject.ps1 -StackProfile GentleAi -ProjectName "mi-app"
```

`Install-ConsultingCopilot.ps1` es un **preflight/diagnóstico** (nombre histórico; no instala). Para automatización puede fijarse `-GentleAiScope Auto|Global|Workspace|Existing`. `Workspace` falla si ya existe global.

## Proyecto generado

- `PROJECT-CONTEXT.md`: entrada de contexto.
- `.cursorignore`: excluye fuentes pesadas de indexado automático.
- `context-budget.mdc` y `/start-task`: un objetivo/dominio y hasta dos archivos iniciales.
- `.cursor/mcp.json`: MCP del proyecto (Draw.io, Backlog, Archi y **Startia** por defecto); nunca Engram.
- `.cdd/changes/`: artefactos CDD completos y versionables.
- Engram: decisiones, hallazgos, estado, resúmenes y punteros.

Sólo `consulting-copilot.mdc` y `context-budget.mdc` son always-on. Las reglas de transcripts, entregables, diagramas, onboarding y CDD se cargan por ámbito o demanda.

## Diagnóstico de proyectos existentes

Tras generar un hijo, validación unificada por perfil:

```powershell
# Windows
pwsh -File .\Test-HubProject.ps1 -TargetPath "..\projects\mi-proyecto" -ExpectedProfile ConsultingAI
```

```bash
# Ubuntu / WSL
pwsh -File ./Test-HubProject.ps1 -TargetPath ../projects/mi-proyecto -ExpectedProfile ConsultingAI
pwsh -File ./Test-GentleAiProject.ps1 -TargetPath ../projects/mi-proyecto
```

Ambos son **read-only** y consumen funciones del módulo (no lanzan scripts hijos que terminen el proceso). `-SkipGentleAiCheck` omite la parte Gentle AI en `Test-HubProject`. No migran automáticamente.

Guía: [docs/MIGRATION-GENTLE-AI.md](docs/MIGRATION-GENTLE-AI.md). Resumen de esta actualización: [docs/CHANGES-2026-08-25.md](docs/CHANGES-2026-08-25.md).

## Pruebas

```powershell
pwsh -NoProfile -File .\tests\Run-Tests.ps1
```

Requiere Pester 5+. Cubre perfiles, Gentle AI, registry, entrypoints, launcher, equivalencia y relocate Windows-only.

Guía multiplataforma (requisitos, comandos Windows/WSL, registry v2, recuperación): [docs/CROSS-PLATFORM.md](docs/CROSS-PLATFORM.md). Resumen de suite: [docs/TEST-SUITE-SUMMARY.md](docs/TEST-SUITE-SUMMARY.md).

## Hub y proyectos hijos

El template vive en `skeleton/` y `overlays/`. Los proyectos viven en `projects/`, quedan ignorados por Git en el padre y reciben su propio `git init`. Para trabajar, abrir siempre el hijo como workspace raíz.

`Move-HubProjectsIa.ps1` es **Windows-only** (no Linux/WSL ni migración Windows↔WSL). Catálogo de scripts: [scripts/README.md](scripts/README.md).

Flujo: [HUB-WORKFLOW.md](HUB-WORKFLOW.md). MCP opcionales: [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md). Piloto: [docs/PILOT-HUB-MULTIPLATFORM.md](docs/PILOT-HUB-MULTIPLATFORM.md).
