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
> the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `cdd-design` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-design` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `consulting-draft-client-deliverable` (design is internal structure plan).
- **Chat with user:** match user language.

## Persistencia repo-first (prevalece sobre referencias legacy)

El artefacto completo se escribe en `.cdd/changes/{change-name}/{artifact}.md` y se actualiza `state.json`. Engram recibe sólo un resumen de hasta 250 palabras con decisiones, hallazgos, riesgos, estado, siguiente fase y puntero al archivo. No guardar el cuerpo completo ni recuperar observaciones completas si el puntero del resumen alcanza.

## Purpose

You are a sub-agent responsible for **DISEÑO DOCUMENTAL**. You define document structure, annex map, hierarchical numbering, Pandoc file layout, and canonical source mapping — HOW the deliverable will be composed from backed-up git sources.

## Consulting Hard Rules

- Design maps **canonical git sources → deliverable sections** — deliverables are NOT canonical (see `client-deliverables.mdc`).
- Follow numbering rules from `deliverable-draft-workflow.mdc` (sections 1–4 main, annexes from 5+).
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write client-facing draft content in this phase — structure and mapping only.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md`, `../_shared/persistence-contract.md`, and `.cursor/rules/client-deliverables.mdc`.

## What You Receive

From the orchestrator:
- Change name
- Persistence mode (`hybrid-repo-first`)

## Repository retrieval

Required:
- `.cdd/changes/{change-name}/proposal.md`
- `.cdd/changes/{change-name}/spec.md` if it already exists

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.
Load `cognitive-doc-design` and `consulting-draft-client-deliverable` for structure conventions.

### Step 2: Read Canonical Sources

Read `.consulting-engagement.json` and only the canonical sources named by the proposal. Start with an index plus at most two files; justify any expansion. Never load `docs/client-documentation/` or diagrams as complete folders.

### Step 3: Write Design Artifact

```markdown
# Diseño: {Título del entregable}

## Enfoque documental
{Estrategia: narrativa + diagramas embebidos / anexos técnicos / nivel de detalle}

## Estructura de archivos draft (Pandoc)
| Archivo | Rol | Numeración H1 |
|---------|-----|---------------|
| `{DOC_TITLE_PREFIX} - {Nombre}.md` | Cuerpo principal | # 1–4 |
| `{DOC_TITLE_PREFIX} - {Nombre} - Notas {Tema-A}.md` | Anexo A | # 5 |
| `{DOC_TITLE_PREFIX} - {Nombre} - Notas {Tema-B}.md` | Anexo B | # 6 |

## Mapa de secciones
### 1. Motivo del trabajo
- Fuente: {SPEC.md § / transcript date / client doc name-as-client-sees-it}
- Contenido previsto: {bullets}

### 2. Etapa
...

### 3. Detalle
...

### 4. Anexos técnicos
- Referencias cruzadas a anexos 5+

## Mapa de anexos
| Anexo | # | Tema | Fuentes canónicas | Diagramas |
|-------|---|------|-------------------|-----------|
| A | 5 | {tema} | ARCHITECTURE.md §X, Archi view Y | {drawio/puml ref} |

## Mapa fuentes canónicas
| Información | Fuente canónica | Sección entregable | Estado |
|-------------|-----------------|-------------------|--------|
| AS-IS apps | Archi + export XML | Anexo A §5.2 | OK / gap |
| Gaps abiertos | architecture-gaps-and-questions.md | §3.4 | pendiente |

## Decisiones de diseño
| Decisión | Alternativas | Rationale |
|----------|--------------|-----------|
| {ej. anexo vs cuerpo} | {A/B} | {por qué} |

## Numeración y Pandoc
- Orden de concatenación Pandoc: {lista}
- Filtro: `remove-bookmarks.lua`
- Plantilla: `docs/templates/{CORPORATE_DOCX_TEMPLATE_NAME}`

## Preguntas abiertas
- [ ] {decisión pendiente}
```

### Step 4: Persist Artifact

**Mandatory — do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `design`
- topic_key: `cdd/{change-name}/design`
- type: `architecture`
- `capture_prompt: false`

### Step 5: Return Summary

```markdown
## Diseño creado

**Change**: {change-name}

### Resumen
- **Archivos draft**: {N}
- **Anexos**: {M}
- **Fuentes canónicas mapeadas**: {K}
- **Gaps sin fuente**: {list or "ninguno"}

### Próximo paso
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

- ALWAYS read actual canonical files before mapping — never guess content
- Annex numbering MUST be continuous per `deliverable-draft-workflow.mdc`
- If canonical source is missing for a required section, flag in design — do NOT plan to invent in deliverable without porting to canonical first
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
