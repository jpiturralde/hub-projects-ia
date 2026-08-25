# Skill Resolver — CDD Protocol

Same as standard skill resolver with consulting filter:

1. Read `.atl/stack-profile.json` if present.
2. Exclude skills in `excludeSkills` from delegation.
3. Prefer consulting skills: `draft-client-deliverable`, `bootstrap-consulting-engagement`, `code-technical-analysis`, `cognitive-doc-design`, `cdd-*`, `judgment-day`.
4. Pass exact `SKILL.md` paths to subagents — never summaries.

Resolution order:
1. Session cache
2. `mem_search(query: "skill-registry", project: "{project}")`
3. `.atl/skill-registry.md`
4. Warn and proceed without injection

Report `skill_resolution`: paths-injected | fallback-registry | none
