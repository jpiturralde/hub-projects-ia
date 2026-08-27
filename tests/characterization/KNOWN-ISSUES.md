# Known issues — caracterización (Fase 2)

Defectos o gaps **documentados**, no corregidos en esta fase (según plan).

| ID | Área | Descripción | Test |
|----|------|-------------|------|
| KI-01 | Cancelación interactiva | ~~Inconclusive~~ — resuelto con `-GentleAiScopeChoice X` / `-Choice` | `GentleAiResolution.Tests.ps1` |
| KI-02 | Fallback Consulting | ~~Inconclusive~~ — resuelto con `-GentleAiCliChoice C` | `GentleAiResolution.Tests.ps1` |
| KI-03 | Proyectos legacy | `test-t01` usa schema v2 y `stackProfile: "full"` sin `requestedProfile` | Manual / registry |
| KI-04 | Staging | ~~Generador escribe directo en `TargetPath`~~ — resuelto en Fase 3 con staging + promoción | `ProjectStaging.Tests.ps1` |
| KI-05 | `skeleton-minimal/README.md` | Menciona Engram en `.cursor/mcp.json`; política actual lo administra Gentle AI | Docs |
| KI-06 | `Copy-ProjectOnboardingLayer` | ~~Wildcard LiteralPath~~ — resuelto con `Get-ChildItem` + `Copy-Item` | `GentleAi.Tests.ps1`, `ProjectStaging.Tests.ps1` |

Los tests marcados **Inconclusive** no cuentan como fallo; se resolverán en Fase 3 con mocks composables o staging.
