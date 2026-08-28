# Guía operativa multiplataforma — Hub Projects IA

El hub genera proyectos hijos con **un solo motor: PowerShell 7 (`pwsh`)** en Windows y Ubuntu/WSL. En Linux hay un launcher Bash (`./scripts/hub`) que solo traduce a esos entrypoints.

## Quick path

1. Instalá `pwsh` 7+ y Pester 5+.
2. Diagnosticá: `./scripts/hub doctor` (WSL) o `Install-ConsultingCopilot.ps1` (Windows).
3. Creá un hijo: `./scripts/hub new ...` / `New-HubProject.ps1`.
4. Abrí `projects/<nombre>/` como workspace raíz (no el hub).
5. Validá: `./scripts/hub test projects/<nombre>` / `Test-HubProject.ps1`.
6. Suite: `pwsh -NoProfile -File ./tests/Run-Tests.ps1`.

## Requisitos

| Herramienta | Obligatorio | Notas |
|-------------|-------------|--------|
| PowerShell 7 (`pwsh`) | Sí | Motor único. En WSL debe ser el `pwsh` **Linux**, no el `.exe` vía `/mnt`. |
| Pester 5+ | Para tests | `Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force` |
| Git | Sí (alta de hijos) | `New-HubProject` hace `git init` en el hijo. |
| Gentle AI CLI | Según perfil | Requerido en ConsultingAI / Full / GentleAi. |
| Go | Sólo si instalás Gentle AI | Flujo de instalación del CLI estable. |
| Node.js / npm | Requerido si activás Draw.io MCP o Backlog MCP | LTS nativo del SO (no `npm.exe` desde WSL). |
| Backlog.md CLI | Requerido si `-IncludeBacklogMcp` | Reutilizado si `backlog --version` ok; si no, instalar con `npm install -g backlog.md@latest --include=optional` (o `-BacklogCliChoice I`). |
| Pandoc / Archi | Opcional | DOCX y Archi MCP; el preflight los marca sin bloquear el alta si no los pedís. |
| `jq` | **No** | El registry usa PowerShell / `System.Text.Json`. |
| `shellcheck` | Opcional | Valida `./scripts/hub` en Ubuntu/WSL. |

No hace falta instalar Engram a mano: lo administra Gentle AI. El generador **nunca** escribe Engram en `.cursor/mcp.json` del hijo.

## Comandos Windows

```powershell
cd C:\ruta\hub-projects-ia

# Preflight (nombre histórico; no instala)
pwsh -NoProfile -File .\scripts\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

# Alta
pwsh -NoProfile -File .\scripts\New-HubProject.ps1 `
  -StackProfile ConsultingAI `
  -ClientDisplayName "ACME" -ClientSlug "acme" `
  -InitiativeDisplayName "Assessment" -InitiativeId "A01"

# Diagnóstico hijo
pwsh -NoProfile -File .\scripts\Test-HubProject.ps1 `
  -TargetPath .\projects\acme-a01 -ExpectedProfile ConsultingAI

# Refresh GETTING-STARTED
pwsh -NoProfile -File .\scripts\Refresh-ProjectGettingStarted.ps1 -AllFromRegistry

# Relocalizar hub (solo Windows nativo; no Windows↔WSL)
pwsh -NoProfile -File .\scripts\Move-HubProjectsIa.ps1 `
  -SourcePath "C:\work\hub-projects-ia" `
  -DestinationPath "D:\repos\hub-projects-ia"

# Tests
pwsh -NoProfile -File .\tests\Run-Tests.ps1
```

## Comandos Ubuntu / WSL

Preferí rutas bajo `/home/...` (no `/mnt/c/...`).

```bash
cd /home/usuario/work/hub-projects-ia

./scripts/hub doctor -StackProfile ConsultingAI
./scripts/hub new -StackProfile ConsultingAI \
  -ClientDisplayName "ACME" -ClientSlug "acme" \
  -InitiativeDisplayName "Assessment" -InitiativeId "A01"
./scripts/hub test projects/acme-a01 -ExpectedProfile ConsultingAI
./scripts/hub refresh --all
./scripts/hub --help

pwsh -NoProfile -File ./tests/Run-Tests.ps1
shellcheck ./scripts/hub
```

Equivalentes directos: [scripts/README.md](../scripts/README.md).

## Perfiles y flujo Gentle AI

| Perfil | Gentle AI | Skeleton |
|--------|-----------|----------|
| ConsultingAI (default) | Requerido; global-first | Consultoría + CDD |
| Full | Igual ConsultingAI; guarda `requestedProfile: Full` | Igual ConsultingAI |
| GentleAi | Requerido | Mínimo desarrollo |
| Consulting | No requerido | Consultoría sin CDD/Engram |

Política resumida:

1. Un solo `gentle-ai` en PATH; si hay varios → stop.
2. Si hay config global Cursor → reutilizar; **nunca** ofrecer workspace.
3. Sin global → preguntar Global / Proyecto / Cancelar.
4. Sin CLI → instalar estable (Go) o, en ConsultingAI, fallback Consulting / cancelar.
5. Global + workspace o Engram duplicado → diagnóstico y stop; no reescribe archivos administrados.

Detalle: [STACK-PROFILES.md](./STACK-PROFILES.md). Migración Gentle AI: [MIGRATION-GENTLE-AI.md](./MIGRATION-GENTLE-AI.md).

### Automatización no interactiva

```powershell
-GentleAiScope Existing          # exige config ya instalada
-GentleAiCliChoice I|X|C         # instalar / cancelar / fallback Consulting
-GentleAiScopeChoice G|P|X       # global / proyecto / cancelar
```

`-EngramPath` está **obsoleto** y se ignora.

## Registry schema v2

`hub-registry.json` usa `schemaVersion: 2` y `relativePath` (`projects/<folder>`).

| Antes (v1) | Ahora (v2) |
|------------|------------|
| `absolutePath` con rutas de máquina | `relativePath` portable |
| Frágil al mover el hub / cambiar OS | Resuelve respecto de la raíz del hub |

Migración:

```powershell
Import-Module ./scripts/lib/ConsultingCopilot.psm1 -Force
Migrate-HubRegistryToV2 -HubRoot (Get-Location)
# Dry-run: -DryRun
```

Crea backup `hub-registry.json.bak-*` (gitignored). `Refresh-ProjectGettingStarted.ps1 -AllFromRegistry` ya lee v2.

## Recuperación ante cancelación o error

| Situación | Qué ocurre | Qué hacer |
|-----------|------------|-----------|
| Cancelás instalación Gentle AI | No se crea el hijo (staging no se promueve) | Reintentar o usar Consulting |
| Falla mid-generación | El destino final no queda a medias: se escribe en staging y se promueve al final | Borrar carpeta vacía/parcial bajo `projects/` si quedó algo manual; revisar mensaje |
| Diagnóstico no saludable (exit 2) | No modifica Gentle AI/Engram | Corregir con herramientas oficiales; no “arreglar” a mano el global |
| Registry corrupto / a medias | Restaurar `hub-registry.json.bak-*` | O re-ejecutar migración dry-run |
| Piloto / prueba | Usar `tests/equivalence/Invoke-HubPilot.ps1` | Limpia proyectos `pilot-hubmp-*` y restaura registry |

Códigos de salida habituales: `0` OK · `1` uso · `2` diagnóstico · `3` dependencia/plataforma (p. ej. Move en Linux).

## Move-HubProjectsIa (Windows-only)

Solo Windows nativo (robocopy). **No** sirve en Linux/WSL ni para migrar Windows↔WSL. En WSL mové el directorio a mano; el registry v2 no depende de absolutos personales.

## Equivalencia y piloto

- Manifiestos normalizados: [../tests/equivalence/ALLOWED-DIFFS.md](../tests/equivalence/ALLOWED-DIFFS.md)
- Goldens: `tests/expected/*/manifest.json`
- Piloto WSL: [PILOT-HUB-MULTIPLATFORM.md](./PILOT-HUB-MULTIPLATFORM.md)

## Decisiones pendientes (fuera de este cierre)

Quedan explícitamente para cambios futuros (ver plan §16):

- Preset oficial `minimal` vs `--component engram,sdd,skills`.
- Retirar `-EngramPath` del surface público.
- Renombrar scripts históricos (mantener aliases).
- CI matricial Windows + Ubuntu.
- Empaquetado/firma del módulo PowerShell.

## Checklist de reproducción

- [ ] `pwsh --version` ≥ 7
- [ ] `Get-Module Pester -ListAvailable` ≥ 5
- [ ] Doctor Gentle AI saludable (o perfil Consulting)
- [ ] `Run-Tests.ps1` en verde
- [ ] Alta de un hijo de prueba y `Test-HubProject`
- [ ] Abrir el hijo como workspace raíz

## Next step

Flujo diario: [../HUB-WORKFLOW.md](../HUB-WORKFLOW.md) · Scripts: [../scripts/README.md](../scripts/README.md) · Plan: [../PLAN_IMPLEMENTACION_HUB_MULTIPLATAFORMA.md](../PLAN_IMPLEMENTACION_HUB_MULTIPLATAFORMA.md)
