# Flujo de trabajo â€” Ingenia Hub IA

Checklist operativo para recorrer el hub desde la creaciÃ³n de un proyecto hasta el trabajo diario en el encargo. Complementa [`README.md`](README.md).

## Vista general

```mermaid
flowchart TB
  subgraph hub["ingenia-hub-ia (repo padre)"]
    install[Install-ConsultingCopilot.ps1]
    skill[Skill create-ingenia-project]
    wrapper[New-HubProject.ps1]
    template[skeleton + overlays]
    registry[hub-registry.json]
  end

  subgraph child["projects/cliente-u01 (repo hijo)"]
    bootstrap[bootstrap-consulting-engagement]
    cdd["/cdd-init + CDD"]
    sdd["/sdd-init + SDD"]
    work[SPEC Â· entregables Â· backlog]
  end

  install --> skill
  skill --> wrapper
  wrapper --> template
  wrapper --> child
  wrapper --> registry
  child --> bootstrap
  bootstrap --> work
  cdd --> work
  sdd --> work
```

---

## Fase 0 â€” Preparar el hub (una vez)

| Paso | AcciÃ³n | DÃ³nde |
|------|--------|-------|
| 1 | Clonar o abrir `ingenia-hub-ia` como **workspace raÃ­z** | RaÃ­z del repo |
| 2 | Ejecutar setup global segÃºn perfiles que usarÃ¡s | `scripts/Install-ConsultingCopilot.ps1` |
| 3 | Verificar MCP y herramientas | [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md) |

```powershell
Set-Location "ruta\a\ingenia-hub-ia\scripts"
.\Install-ConsultingCopilot.ps1 -StackProfile Full
```

---

## Fase 1 â€” Crear proyecto hijo

| Paso | AcciÃ³n | DÃ³nde |
|------|--------|-------|
| 1 | Pedir nuevo proyecto en Cursor o invocar script | Skill `create-ingenia-project` o `New-HubProject.ps1` |
| 2 | Confirmar perfil, cliente/slug, iniciativa (Consulting/Full) o nombre (GentleAi) | Chat o parÃ¡metros PS |
| 3 | Revisar resumen: carpeta `projects/<nombre>/`, perfil, MCP | Antes de ejecutar |
| 4 | Ejecutar generaciÃ³n | `scripts/New-HubProject.ps1` |
| 5 | Verificar registro | `hub-registry.json` |

**ConvenciÃ³n de carpeta:** `projects/{client-slug}-{initiative-id}/` (ej. `iplan-u01`).

**Validaciones post-creaciÃ³n:**

- [ ] Existe `projects/<nombre>/` con skeleton y overlay correcto
- [ ] Existe `projects/<nombre>/.git/`
- [ ] Entrada en `hub-registry.json`
- [ ] `git status` en el **padre** no lista el hijo (gitignore activo)

---

## Fase 2 â€” Abrir el hijo como workspace

| Paso | AcciÃ³n |
|------|--------|
| 1 | File â†’ Open Folder â†’ `projects/<nombre>/` (o dejar que el script abra Cursor con `cursor <ruta>`) |
| 2 | Ejecutar **`/onboarding`** o leer **`docs/GETTING-STARTED.md`** |
| 3 | Confirmar que las reglas del encargo (no del hub) estÃ¡n activas |
| 4 | Cursor Settings â†’ MCP â€” verificar `engram` y demÃ¡s servidores en verde |
| 5 | Ajustar rutas en `.cursor/mcp.json` si hay placeholders (archi, backlog) |

> **Importante:** no trabajes entregables de cliente con el workspace en la raÃ­z del hub. Los MCP del hijo (Engram, etc.) **no cargan** mientras el workspace sea el padre.

---

## Fase 3 â€” Bootstrap del encargo

SegÃºn perfil generado:

### Consulting / Full

| Paso | AcciÃ³n |
|------|--------|
| 1 | Skill **`bootstrap-consulting-engagement`** â€” completar README, SPEC, ARCHITECTURE |
| 2 | Copiar plantilla Word corporativa a `docs/templates/` |
| 3 | Configurar exports ArchiMate segÃºn metadata en `.consulting-engagement.json` |

### Full (adicional)

| Paso | AcciÃ³n |
|------|--------|
| 1 | `/cdd-init` â€” inicializar flujo CDD |
| 2 | `/cdd-new <entregable>` â€” primer ciclo de diseÃ±o |

### GentleAi

| Paso | AcciÃ³n |
|------|--------|
| 1 | `/sdd-init` â€” inicializar flujo SDD |
| 2 | `/sdd-new <cambio>` â€” primer cambio |

---

## Fase 4 â€” Trabajo cotidiano (en el hijo)

Flujo tÃ­pico de consultorÃ­a (Consulting/Full):

```mermaid
flowchart LR
  A[Reuniones / material cliente] --> B[transcripts/ Â· docs/client-documentation/]
  B --> C[CanÃ³nicos SPEC Â· ARCHITECTURE Â· ArchiMate]
  C --> D[backlog Â· meetings/]
  C --> E[docs/draft/]
  E --> F[docs/deliverables/]
```

Reglas clave en el hijo:

- **`transcripts/`** â€” inmutable salvo confirmaciÃ³n explÃ­cita
- **`docs/deliverables/`** â€” sin referencias internas al repo
- CanÃ³nicos antes que borradores de cliente

Skills Ãºtiles en el dÃ­a a dÃ­a (Consulting/Full):

- **`architect-copilot`** â€” estado del encargo, prioridades, bloqueos
- **`transcription-to-actions`** â€” derivar backlog/gaps desde `transcripts/`
- **`draft-client-deliverable`** â€” redactar material que saldrÃ¡ al cliente

---

## RetroalimentaciÃ³n al template (hub)

| QuÃ© | DÃ³nde | Notas |
|-----|-------|-------|
| Mejoras al molde | `skeleton/`, `overlays/` en **ingenia-hub-ia** | Commitear en el padre |
| Lecciones de un encargo | Portar manualmente al skeleton | No hay auto-sync a hijos existentes |
| Nuevo hijo | `New-HubProject.ps1` | Hereda el template actual |

**Fuera de v1:** sincronizaciÃ³n automÃ¡tica de mejoras del template hacia proyectos ya generados.

---

## CatÃ¡logo y trazabilidad

| Fuente | Contenido |
|--------|-----------|
| [`hub-registry.json`](hub-registry.json) | Proyectos generados desde el hub (mÃ¡quina) |
| Git de cada hijo | Historial del encargo |
| Git del padre | EvoluciÃ³n del template (sin `projects/`*) |

---

## Troubleshooting

| Problema | SoluciÃ³n |
|----------|----------|
| Carpeta destino no vacÃ­a | Vaciar, usar `-Force`, o `-ProjectFolderName` distinto |
| `folderName` duplicado en registry | Elegir otro nombre o `-Force` |
| Hijo aparece en `git status` del padre | Debe estar bajo `projects/`; revisar `.gitignore` |
| `gentle-ai` no encontrado | `Install-ConsultingCopilot.ps1 -StackProfile Full` |
| Quiero ruta custom fuera de `projects/` | Usar `New-ConsultingCopilotProject.ps1` directo; advertencia: sin gitignore automÃ¡tico |

---

## Checklist rÃ¡pido

**Crear encargo Consulting/Full**

- [ ] Setup global en hub
- [ ] Skill o script â†’ proyecto en `projects/`
- [ ] Abrir hijo como workspace
- [ ] `bootstrap-consulting-engagement`
- [ ] (Full) `/cdd-init`
- [ ] Plantilla Word en `docs/templates/`

**Crear app GentleAi**

- [ ] Setup global con perfil GentleAi
- [ ] `New-HubProject.ps1 -StackProfile GentleAi`
- [ ] Abrir hijo â†’ `/sdd-init`
