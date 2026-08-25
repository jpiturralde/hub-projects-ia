# Ingenia Hub IA — Consulting Copilot

Repositorio **padre** que concentra el template Consulting Copilot y orquesta la creación de proyectos hijos. Evolucionás el molde aquí; cada encargo o app vive en su propia carpeta bajo `projects/`.

## Hub vs proyecto hijo

| Zona | Responsabilidad | Git |
|------|-----------------|-----|
| Raíz (`skeleton/`, `overlays/`, `scripts/`, docs) | Template y generación | Repo padre (`ingenia-hub-ia`) |
| [`projects/`](projects/) | Encargos y apps generados | **Gitignored** en el padre; cada hijo tiene su propio `git init` |

**Crear proyectos:** abrí **esta carpeta** como workspace raíz en Cursor.

**Trabajar en un encargo:** abrí `projects/<nombre>/` como workspace raíz (ej. `projects/iplan-u01/`).

Flujo operativo detallado: [`HUB-WORKFLOW.md`](HUB-WORKFLOW.md).

## Perfiles disponibles

| Perfil | Uso |
|--------|-----|
| **Consulting** | Solo consultoría (entregables, diagramas, ArchiMate) |
| **Full** | Consultoría + Gentle AI (`gentle-ai install` + overlay CDD) |
| **GentleAi** | Solo desarrollo (SDD, Engram) |

Detalle: [docs/STACK-PROFILES.md](docs/STACK-PROFILES.md).

## Requisitos

- **Windows**: PowerShell 5.1+
- **IDE con MCP** (p. ej. [Cursor Desktop](https://cursor.com))
- Perfil **Full/GentleAi**: `gentle-ai` + `engram` en PATH
- Perfil **Consulting/Full**: Node.js LTS (draw.io MCP), Pandoc (opcional)

MCP: [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md)

## Setup global (una vez)

```powershell
Set-Location "ruta\a\ingenia-hub-ia\scripts"
.\Install-ConsultingCopilot.ps1 -StackProfile Full
```

## Crear un proyecto hijo

### Opción A — Cursor (recomendado)

Pedí en el chat: *"crear proyecto Full para IPLAN U01"* (o similar). La skill **`create-ingenia-project`** guía el flujo y ejecuta el script tras tu confirmación.

### Opción B — PowerShell directo

```powershell
Set-Location "ruta\a\ingenia-hub-ia\scripts"

# Consultoría
.\New-HubProject.ps1 `
  -StackProfile Consulting `
  -ClientDisplayName "ACME" -ClientSlug "acme" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"

# Full (CDD + entregables)
.\New-HubProject.ps1 `
  -StackProfile Full `
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"

# Solo desarrollo
.\New-HubProject.ps1 `
  -StackProfile GentleAi `
  -ProjectName "mi-app"
```

Convención de carpeta: `projects/{client-slug}-{initiative-id}/` (Consulting/Full) o slug del nombre (GentleAi). Override: `-ProjectFolderName`.

Retrocompat: `New-ConsultingCopilotProject.ps1` sigue disponible para rutas absolutas custom fuera del hub.

## Después de generar

1. Abrí `projects/<nombre>/` como workspace raíz en Cursor.
2. Revisá `.cursor/mcp.json` en el hijo.
3. **Consulting/Full:** skill `bootstrap-consulting-engagement` para completar SPEC.
4. **Full:** `/cdd-init` → `/cdd-new <entregable>`.
5. **GentleAi:** `/sdd-init` → `/sdd-new <cambio>`.
6. Copiá plantilla Word a `docs/templates/` (Consulting/Full).

## Catálogo de proyectos

[`hub-registry.json`](hub-registry.json) registra localmente los hijos generados (ruta, perfil, fecha). No reemplaza el control de versiones de cada hijo.

## Jerarquía `projects/` y gitignore

Los hijos **no** se commitean en el repo padre:

```gitignore
projects/*
!projects/.gitkeep
```

Cada hijo recibe `git init` automático (salvo `-SkipGitInit`). Si generás fuera de `projects/`, el gitignore del hub no aplica — usá la convención canónica.

## Mantenimiento del template

Propagá mejoras a:

- `skeleton/` — base Consulting
- `skeleton-minimal/` — base GentleAi
- `overlays/consulting/` y `overlays/full/`

Los hijos existentes **no** se actualizan solos; regenerá proyectos nuevos o portá cambios a mano.

## Tokens y metadata

- Placeholders: [SKELETON-PLACEHOLDERS.md](SKELETON-PLACEHOLDERS.md)
- Metadata encargo (hijo): `.consulting-engagement.json`
- Metadata dev (hijo): `.project-profile.json`

## Relación con ingenia-template-ia

`ingenia-hub-ia` evoluciona el contenido de `ingenia-template-ia` con la capa hub (`projects/`, `New-HubProject.ps1`, skill y reglas). Los scripts base (`New-ConsultingCopilotProject.ps1`, `ConsultingCopilot.psm1`) se mantienen compatibles.
