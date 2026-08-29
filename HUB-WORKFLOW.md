# Flujo de trabajo — Hub Projects IA

Motor único: **PowerShell 7** (`pwsh`) en Windows y Ubuntu/WSL. Guía completa: [docs/CROSS-PLATFORM.md](docs/CROSS-PLATFORM.md). Entrypoints: [scripts/README.md](scripts/README.md).

## 1. Diagnosticar

```powershell
# Windows
Set-Location "C:\ruta\hub-projects-ia\scripts"
pwsh -NoProfile -File .\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI
```

```bash
# Ubuntu / WSL
cd /home/usuario/work/hub-projects-ia
./scripts/hub doctor -StackProfile ConsultingAI
# equivalente: pwsh -File ./scripts/Install-ConsultingCopilot.ps1 ...
./scripts/hub env projects/<nombre>   # entorno del hijo (detect-only)
```

El diagnóstico es read-only (nombre histórico `Install-*`; no instala). Si hay varios ejecutables o global + workspace, corregir primero; el generador no toca archivos administrados.

Para **retrofit** de `requires` (schema 4) + GETTING-STARTED + doctor en hijos ya registrados — **mismo writer** que `Refresh-ProjectGettingStarted.ps1` (no hay script de copy-in):

```bash
./scripts/hub refresh --all
# o un hijo: ./scripts/hub refresh projects/<nombre>
# manual fuera del registry:
# pwsh -File ./scripts/Refresh-ProjectGettingStarted.ps1 -TargetPath /ruta/absoluta/hijo
```

Doctor de entorno (detect-only, mensajes en español): hijo `scripts/Test-ProjectEnvironment.ps1` o `./scripts/hub env projects/<nombre>`. Exit `2` si falla un tool required o el MCP local está `broken`.

## 2. Generar

```powershell
pwsh -NoProfile -File .\New-HubProject.ps1 `
  -StackProfile ConsultingAI `
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"
```

Antes de crear el hijo:

1. Resuelve CLI Gentle AI.
2. Detecta global y workspace.
3. Reutiliza global si existe.
4. Sólo sin global pregunta Global/Proyecto/Cancelar.
5. Luego copia skeleton y overlays, escribe metadata, refresca registry y ejecuta `git init`.

## 3. Abrir el hijo

Abrir `projects/<nombre>/` como workspace raíz, no el hub. Leer `docs/GETTING-STARTED.md` y ejecutar `/start-task`.

MCP local esperado: Draw.io, Backlog y/o Archi según opciones; **Startia** por defecto (`-IncludeStartiaMcp`). Engram debe aparecer por la configuración administrada por Gentle AI, no duplicado en el proyecto.

## 4. Trabajar con contexto acotado

1. Un objetivo y un dominio por chat.
2. `PROJECT-CONTEXT.md` + índice.
3. Hasta dos archivos de contenido.
4. Engram sólo por decisiones/hallazgos/punteros relevantes.
5. Fuentes pesadas por archivo exacto.

## 5. Elegir ruta

| Necesidad | Ruta |
|---|---|
| Tarea acotada | Ejecución directa |
| Análisis especializado | Agente cognitivo + skill de dominio |
| Entregable complejo | CDD |
| Desarrollo explícito | SDD |

CDD guarda el contenido completo en `.cdd/changes/` y memoria resumida en Engram.

## 6. Entregar

- Hechos confirmados primero en fuentes canónicas.
- Borradores en `docs/draft/` sin referencias internas.
- Antes de exportar: verify + revisiones client-facing y canonical-alignment.
- Transcripts permanecen inmutables salvo confirmación explícita.

## 7. Diagnosticar un hijo existente

```powershell
# Windows
pwsh -File .\Test-HubProject.ps1 -TargetPath "..\projects\iplan-prev-2142" -ExpectedProfile ConsultingAI
```

```bash
# Ubuntu / WSL
pwsh -File ./Test-GentleAiProject.ps1 -TargetPath ../projects/iplan-prev-2142
```

El resultado no aplica migraciones. Cualquier corrección de Gentle AI debe hacerse con comandos administrados y revisión previa.

## 8. Re-sync manual Startia → skeleton (wrappers)

Cuatro skills del skeleton son **wrappers** sobre el catálogo Startia (no borrar; no sync automático a hijos):

| Wrapper en `skeleton/.cursor/skills/` | Canónico MCP |
|---|---|
| `architect-copilot` | `architect-copilot` |
| `transcription-to-actions` | `transcription-to-actions` |
| `consulting-code-technical-analysis` | `code-technical-analysis` |
| `consulting-draft-client-deliverable` | `draft-ingenia-gdocs-deliverable` |

Checklist al actualizar contenido genérico:

1. En un workspace con MCP **startia** activo: `list_skills` / `get_skill` de la versión **approved**.
2. Fusionar el contenido genérico en el wrapper del skeleton **preservando** la capa hub (rutas, placeholders `{{…}}`, reglas locales).
3. Abrir PR al hub. Los hijos ya generados **no** se actualizan solos (igual que el resto del template).
4. No reinstalar estos skills en `~/.cursor/skills`.

Detalle: `skeleton/docs/MCP-PREREQUISITOS.md` § 5 y rule `startia-skill-wrappers.mdc`.

## 9. Propagar plantilla a hijos (opt-in)

La propagación de la capa plantilla del hub hacia proyectos ya generados es **solo opt-in** vía CLI. **No** hay auto-sync en generación, CI ni hooks.

```bash
# Ubuntu / WSL — plan only (sin worktree ni writes)
./scripts/hub propagate --all --dry-run
./scripts/hub propagate iplan-prev-2142 --dry-run

# Apply: escribe solo en worktree/branch hub-side (.hub-propagate-worktrees/), nunca en el checkout live
./scripts/hub propagate iplan-prev-2142 --branch hub/propagate-yyyyMMdd
./scripts/hub propagate --profile ConsultingAI --include-mcp-merge
```

```powershell
pwsh -NoProfile -File .\Propagate-HubTemplateToChildren.ps1 -All -DryRun
pwsh -NoProfile -File .\Propagate-HubTemplateToChildren.ps1 -FolderName iplan-prev-2142
```

Contratos v1:

- **DryRun** = plan de paths (`Get-HubPropagatablePaths`); sin worktree, sin `Sync-HubTemplatePaths`.
- **Apply** = worktree hub-side únicamente; gate `.git` usable (`rev-parse`), no solo el flag registry `gitInitialized`.
- Selección registry v2: `-FolderName` / `-All` / `-StackProfile`. **Full ↔ ConsultingAI** se co-incluyen (mismo golden `consulting-ai`).
- Engagement (transcripts, drafts, gaps, backlog, `.cdd/changes`) y hybrid (mcp/README/stack-profile/…) no se sobrescriben por defecto.
