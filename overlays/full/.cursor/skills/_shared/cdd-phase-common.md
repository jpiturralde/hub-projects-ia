# CDD Phase Common â€” Shared Contract

## Section A: Load Skills

Read skill paths injected by the orchestrator before work. Also load:
- `draft-client-deliverable` when writing client-facing content
- `client-deliverables.mdc` rules when touching `docs/deliverables/`

Filter registry using `.atl/stack-profile.json` when present â€” exclude dev-only skills listed in `excludeSkills`.

## Section B: Retrieval (Engram)

1. `mem_search(query: "{topic_key}", project: "{project}")` â†’ observation ID
2. `mem_get_observation(id: {id})` â†’ full content (mandatory)

Required reads by phase:

| Phase | Required topic keys |
|-------|---------------------|
| cdd-propose | `cdd/{change}/explore` (optional) |
| cdd-spec | `cdd/{change}/proposal` |
| cdd-design | `cdd/{change}/proposal` |
| cdd-tasks | `cdd/{change}/spec`, `cdd/{change}/design` |
| cdd-apply | `cdd/{change}/tasks`, spec, design, apply-progress (if exists) |
| cdd-verify | spec, tasks, apply-progress |
| cdd-archive | all artifacts for change |

Also read **SPEC.md** as canonical scope reference for consulting projects.

## Section C: Persistence (Engram)

```
mem_save(
  title: "cdd/{change-name}/{artifact-type}",
  topic_key: "cdd/{change-name}/{artifact-type}",
  type: "architecture",
  project: "{project}",
  capture_prompt: false,
  content: "{artifact markdown}"
)
```

## Section D: Result Contract

Every phase returns:
- `status`: done | blocked | partial
- `executive_summary`
- `artifacts`
- `next_recommended`
- `risks`
- `skill_resolution`

## Prohibited in CDD

- Running unit tests, builds, or coverage as verification
- Creating PRs unless user explicitly requests git workflow
- Writing internal repo paths in client deliverables
