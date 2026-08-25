---
name: cdd-init
description: "Trigger: cdd init, iniciar cdd, /cdd-init. Initialize consulting CDD context, skill registry, and Engram persistence."
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
> the dedicated `cdd-init` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-init` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

## Language Domain Contract

- **CDD internal artifacts** (registry, init context): neutral professional Spanish unless the user requests otherwise.
- **Client deliverables** (future phases): formal Spanish per `consulting-draft-client-deliverable`.
- **Chat with user:** match user language.

## Activation Contract

Run when the orchestrator/user asks to initialize CDD in a consulting project. You are the phase executor: do the work yourself, do not delegate.

## Persistencia repo-first

Escribir el contexto completo en `.cdd/project-context.md` y usar Engram sólo para un resumen de hasta 250 palabras con decisiones, riesgos y puntero. El modo fijo del perfil es `hybrid-repo-first`.

## Consulting Hard Rules

- This is a **documentation/consulting** engagement — do NOT detect or configure `strict_tdd`, test runners, coverage, or dev CI.
- Do NOT create `openspec/`: CDD usa `.cdd/` y Engram como memoria resumida.
- Do NOT include dev-only skills in the registry: `go-testing`, `branch-pr`, `chained-pr`, `work-unit-commits`.
- Do NOT run unit tests, builds, or PR workflows as part of init.

## Shared Contract

> Follow `../_shared/cdd-phase-common.md` for skill loading (Section A), persistence (Section C), and result envelope (Section D).
> Also read `../_shared/engram-convention.md`, `../_shared/skill-resolver.md`, and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Project name (or derive from workspace)
- Persistence mode: `hybrid-repo-first`

## Execution Steps

### Step 1: Read Engagement Metadata

Read `.consulting-engagement.json` (fallback `.workbench-metadata.json`) and extract:
- `stackProfile`, client/initiative names, slugs, ArchiMate export filenames, doc title prefix, consultancy metadata
- Confirm `stackProfile` is `consulting-ai` (accept `full` only as legacy metadata)

### Step 2: Inspect Project Context

Read canonical consulting files when present:
- `README.md`, `SPEC.md`, `ARCHITECTURE.md`
- `docs/architecture-gaps-and-questions.md`
- `.atl/stack-profile.json` (confirm `excludeSkills`)

Summarize: engagement type (documentation-only vs mixed), canonical source layout, deliverable draft folder state.

### Step 3: Build Skill Registry

Scan `.cursor/skills/` (project + overlays) and build `.atl/skill-registry.md`:
- List each skill with trigger/description and absolute `SKILL.md` path
- **Exclude** dev-only skills: `go-testing`, `branch-pr`, `chained-pr`, `work-unit-commits`
- Also apply `excludeSkills` from `.atl/stack-profile.json` when present
- **Prefer** consulting skills: `consulting-draft-client-deliverable`, `bootstrap-consulting-engagement`, `consulting-code-technical-analysis`, `cognitive-doc-design`, `cdd-*`, `judgment-day`

Do NOT configure or mention `strict_tdd`.

### Step 4: Persist Initialization

1. Write full init context to `.cdd/project-context.md`.
2. Save a compact Engram summary:
```
mem_save(
  title: "cdd-init/{project}",
  topic_key: "cdd-init/{project}",
  type: "architecture",
  project: "{project}",
  capture_prompt: false,
  content: "{summary, decisions, risks, pointer to .cdd/project-context.md}"
)
```

The repository context MUST include engagement metadata, canonical paths, registry snapshot, excluded dev skills and next phase.

Also save `skill-registry` observation when Engram is available.

### Step 5: Return Result

Return envelope per **Section D** from `../_shared/cdd-phase-common.md`.

## Result Contract Fields

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | One paragraph: engagement initialized, registry built, persistence mode |
| `artifacts` | Paths/IDs: `.atl/skill-registry.md`, Engram `cdd-init/{project}`, `skill-registry` |
| `next_recommended` | `cdd-explore` or `bootstrap-consulting-engagement` if SPEC is empty |
| `risks` | Missing metadata, empty SPEC, no Engram, incomplete canonical files |
| `skill_resolution` | `paths-injected` \| `fallback-registry` \| `none` |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Project context | `cdd-init/{project}` |
| Skill registry | `skill-registry` (project scope) |

## Rules

- NEVER set or infer `strict_tdd`
- NEVER include excluded dev skills in the active registry
- ALWAYS read `.consulting-engagement.json` before building context
- If Engram is unavailable, still write `.atl/skill-registry.md` and return `partial` with risk noted
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
