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
| `Test-GentleAiProject.ps1` | Diagnóstico read-only Gentle AI / Engram |
| `Refresh-ProjectGettingStarted.ps1` | Regenera GETTING-STARTED (ruta o registry v2) |
| `Move-HubProjectsIa.ps1` | Relocalización **Windows-only** |

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
