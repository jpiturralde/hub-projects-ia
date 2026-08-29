# Scripts públicos — Hub Projects IA

Motor único: **PowerShell 7** (`pwsh`). Los mismos entrypoints sirven en Windows y Ubuntu/WSL.

## Mapa

| Script | Rol |
|--------|-----|
| `hub` | Launcher Bash Ubuntu/WSL → entrypoints `pwsh` (sin lógica de negocio) |
| `Install-ConsultingCopilot.ps1` | Preflight / diagnóstico (nombre histórico; **no instala**) |
| `New-HubProject.ps1` | Orquestador canónico → `projects/` + git + registry |
| `New-ConsultingCopilotProject.ps1` | Generador central (cualquier `TargetPath`) |
| `New-IngeniaTemplateProject.ps1` | Alias → ConsultingAI |
| `New-IngeniaCursorProject.ps1` | Alias → `New-IngeniaTemplateProject.ps1` |
| `Test-HubProject.ps1` | Smoke read-only del hijo (estructura + Gentle AI) |
| `Test-HubChildEnvironment.ps1` | Diagnóstico de entorno del hijo (`requires` / tools / MCP local) |
| `templates/Test-ProjectEnvironment.ps1` | Plantilla emitida al hijo como `scripts/Test-ProjectEnvironment.ps1` |
| `Test-GentleAiProject.ps1` | Diagnóstico read-only Gentle AI / Engram |
| `Refresh-ProjectGettingStarted.ps1` | Regenera GETTING-STARTED + upsert `requires` + re-emite doctor (ruta o registry v2) |
| `Move-HubProjectsIa.ps1` | Relocalización **Windows-only** (no Linux/WSL; no Windows↔WSL) |

## Windows

```powershell
cd C:\ruta\hub-projects-ia\scripts
pwsh -NoProfile -File .\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

pwsh -NoProfile -File .\New-HubProject.ps1 `
  -StackProfile ConsultingAI `
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"

pwsh -NoProfile -File .\Test-HubProject.ps1 `
  -TargetPath "..\projects\iplan-u01" `
  -ExpectedProfile ConsultingAI
```

## Ubuntu / WSL

Launcher recomendado (solo traduce a los entrypoints PowerShell; no duplica lógica):

```bash
cd /home/usuario/work/hub-projects-ia
./scripts/hub doctor -StackProfile ConsultingAI
./scripts/hub new -StackProfile ConsultingAI \
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" \
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"
./scripts/hub test projects/iplan-u01 -ExpectedProfile ConsultingAI
./scripts/hub env projects/iplan-u01
./scripts/hub refresh projects/iplan-u01
./scripts/hub refresh --all
./scripts/hub --help
```

Invocación directa equivalente:

```bash
cd /home/usuario/work/hub-projects-ia/scripts
pwsh -NoProfile -File ./Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

pwsh -NoProfile -File ./New-HubProject.ps1 \
  -StackProfile ConsultingAI \
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" \
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"

pwsh -NoProfile -File ./Test-HubProject.ps1 \
  -TargetPath ../projects/iplan-u01 \
  -ExpectedProfile ConsultingAI

pwsh -NoProfile -File ./Refresh-ProjectGettingStarted.ps1 -AllFromRegistry
```

## Notas

- Preferí rutas bajo el filesystem nativo (en WSL: `/home/...`, no `/mnt/c/...`).
- `-EngramPath` está **obsoleto** y se ignora (Engram lo administra Gentle AI).
- Diagnósticos (`Install-*`, `Test-*`) son read-only respecto de Gentle AI/Engram administrados.
- Registry: `hub-registry.json` schema **v2** con `relativePath` (portable).
- `Move-HubProjectsIa.ps1` es **solo Windows nativo** (robocopy). En Ubuntu/WSL mové el directorio a mano; el registry v2 no depende de rutas absolutas personales.

## Validación de entorno (`hub env` / doctor hijo)

- Hijo: `scripts/Test-ProjectEnvironment.ps1` (emitido en New/Refresh; plantilla hub `templates/Test-ProjectEnvironment.ps1`).
- Hub: `./scripts/hub env <ruta>` → `Test-HubChildEnvironment.ps1` (mismo vector `requires`).
- Copy de mensajes en **español**. Detect-only: no instala ni repara.
- Exit `0` = OK; exit `2` = falla un tool `required` **o** MCP local `broken`.
- `not-materialized` ≠ `broken`; falla el exit solo si drawio/backlog/archi son required.
- Retrofit registry: `./scripts/hub refresh --all` (mismo writer que `Refresh-ProjectGettingStarted.ps1`; no hay script de copy-in).
- Manual fuera del registry: `pwsh -File ./Refresh-ProjectGettingStarted.ps1 -TargetPath <abs>`.
