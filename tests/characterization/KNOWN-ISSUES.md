# Known issues — caracterización (Fase 2)

Defectos o gaps **documentados**, no corregidos en esta fase (según plan).

| ID | Área | Descripción | Test |
|----|------|-------------|------|
| KI-01 | Cancelación interactiva | `Read-ConsultingChoice` / `Read-ConsultingPromptYesNo` no mockeados de forma centralizada; cancelar no se caracteriza end-to-end | `GentleAiResolution.Tests.ps1` — Inconclusive |
| KI-02 | Fallback Consulting | Fallback ConsultingAI→Consulting requiere mock interactivo | `GentleAiResolution.Tests.ps1` — Inconclusive |
| KI-03 | Proyectos legacy | `test-t01` usa schema v2 y `stackProfile: "full"` sin `requestedProfile` | Manual / registry |
| KI-04 | Staging | Generador escribe directo en `TargetPath`; cancelación tardía puede dejar carpeta vacía creada por `Test-ConsultingTargetPath` | Fase 3 |
| KI-05 | `skeleton-minimal/README.md` | Menciona Engram en `.cursor/mcp.json`; política actual lo administra Gentle AI | Docs |
| KI-06 | `Copy-ProjectOnboardingLayer` | `Copy-Item -LiteralPath (Join-Path $skillSrc '*')` falla en Linux/PowerShell — bloquea generación GentleAi en WSL | `GentleAi.Tests.ps1` — Skip en Linux |

Los tests marcados **Inconclusive** no cuentan como fallo; se resolverán en Fase 3 con mocks composables o staging.
