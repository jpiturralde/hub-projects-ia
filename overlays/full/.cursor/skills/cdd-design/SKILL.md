---
name: cdd-design
description: "Create CDD document structure, annex map, and canonical source mapping. Trigger: orchestrator launches cdd-design for a change."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
  delegate_only: true
---

> **ORCHESTRATOR GATE**: If you loaded this skill via the `skill()` tool, you are
> the ORCHESTRATOR â€” STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `cdd-design` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-design` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor â€” execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `draft-client-deliverable` (design is internal structure plan).
- **Chat with user:** match user language.

## Purpose

You are a sub-agent responsible for **DISEÃ‘O DOCUMENTAL**. You define document structure, annex map, hierarchical numbering, Pandoc file layout, and canonical source mapping â€” HOW the deliverable will be composed from backed-up git sources.

## Consulting Hard Rules

- Design maps **canonical git sources â†’ deliverable sections** â€” deliverables are NOT canonical (see `client-deliverables.mdc`).
- Follow numbering rules from `deliverable-draft-workflow.mdc` (sections 1â€“4 main, annexes from 5+).
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write client-facing draft content in this phase â€” structure and mapping only.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md`, `../_shared/persistence-contract.md`, and `.cursor/rules/client-deliverables.mdc`.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)

## Engram Retrieval

Required:
- `cdd/{change-name}/proposal` (mandatory)
- `cdd/{change-name}/spec` (optional â€” may run parallel with cdd-spec; read if exists)

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.
Load `cognitive-doc-design` and `draft-client-deliverable` for structure conventions.

### Step 2: Read Canonical Sources

Before designing, inspect actual sources:
- `ARCHITECTURE.md`, `docs/architecture-gaps-and-questions.md`
- `docs/diagrams/` (Archi export, drawio, puml)
- `docs/client-documentation/`
- Existing files in `docs/draft/` (if any)
- `.consulting-engagement.json` for doc title prefix and naming

### Step 3: Write Design Artifact

```markdown
# DiseÃ±o: {TÃ­tulo del entregable}

## Enfoque documental
{Estrategia: narrativa + diagramas embebidos / anexos tÃ©cnicos / nivel de detalle}

## Estructura de archivos draft (Pandoc)
| Archivo | Rol | NumeraciÃ³n H1 |
|---------|-----|---------------|
| `{DOC_TITLE_PREFIX} - {Nombre}.md` | Cuerpo principal | # 1â€“4 |
| `{DOC_TITLE_PREFIX} - {Nombre} - Notas {Tema-A}.md` | Anexo A | # 5 |
| `{DOC_TITLE_PREFIX} - {Nombre} - Notas {Tema-B}.md` | Anexo B | # 6 |

## Mapa de secciones
### 1. Motivo del trabajo
- Fuente: {SPEC.md Â§ / transcript date / client doc name-as-client-sees-it}
- Contenido previsto: {bullets}

### 2. Etapa
...

### 3. Detalle
...

### 4. Anexos tÃ©cnicos
- Referencias cruzadas a anexos 5+

## Mapa de anexos
| Anexo | # | Tema | Fuentes canÃ³nicas | Diagramas |
|-------|---|------|-------------------|-----------|
| A | 5 | {tema} | ARCHITECTURE.md Â§X, Archi view Y | {drawio/puml ref} |

## Mapa fuentes canÃ³nicas
| InformaciÃ³n | Fuente canÃ³nica | SecciÃ³n entregable | Estado |
|-------------|-----------------|-------------------|--------|
| AS-IS apps | Archi + export XML | Anexo A Â§5.2 | OK / gap |
| Gaps abiertos | architecture-gaps-and-questions.md | Â§3.4 | pendiente |

## Decisiones de diseÃ±o
| DecisiÃ³n | Alternativas | Rationale |
|----------|--------------|-----------|
| {ej. anexo vs cuerpo} | {A/B} | {por quÃ©} |

## NumeraciÃ³n y Pandoc
- Orden de concatenaciÃ³n Pandoc: {lista}
- Filtro: `remove-bookmarks.lua`
- Plantilla: `docs/templates/{CORPORATE_DOCX_TEMPLATE_NAME}`

## Preguntas abiertas
- [ ] {decisiÃ³n pendiente}
```

### Step 4: Persist Artifact

**Mandatory â€” do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `design`
- topic_key: `cdd/{change-name}/design`
- type: `architecture`
- `capture_prompt: false`

### Step 5: Return Summary

```markdown
## DiseÃ±o creado

**Change**: {change-name}

### Resumen
- **Archivos draft**: {N}
- **Anexos**: {M}
- **Fuentes canÃ³nicas mapeadas**: {K}
- **Gaps sin fuente**: {list or "ninguno"}

### PrÃ³ximo paso
Listo para cdd-tasks (checklist secciones/anexos/diagramas).
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Document structure and canonical mapping summary |
| `artifacts` | Engram `cdd/{change}/design` ID |
| `next_recommended` | `cdd-tasks` |
| `risks` | Missing canonical sources, numbering conflicts, unresolved open questions |
| `skill_resolution` | Skills loaded |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Design | `cdd/{change}/design` |

## Rules

- ALWAYS read actual canonical files before mapping â€” never guess content
- Annex numbering MUST be continuous per `deliverable-draft-workflow.mdc`
- If canonical source is missing for a required section, flag in design â€” do NOT plan to invent in deliverable without porting to canonical first
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
