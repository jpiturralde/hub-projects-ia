# Resumen suite Pester — cierre multiplataforma

Fecha: 2026-08-27 · Rama: `feature/hub-multiplatform` · Host: WSL/Ubuntu

## Cómo regenerar

```bash
pwsh -NoProfile -File ./tests/Run-Tests.ps1
```

## Resultado de referencia (cierre Fase 12)

Ejecución al cierre (WSL, 2026-08-27):

| Métrica | Valor |
|---------|-------|
| Passed | 108 |
| Failed | 0 |
| Skipped | 2 (relocate físico Windows-only) |
| Inconclusive | 1 (caracterización Gentle AI sin mcp.json local) |
| `shellcheck ./scripts/hub` | exit 0 |

Suites incluidas: `unit`, `characterization`, `integration`, `equivalence`, más legacy `ConsultingCopilot.Tests.ps1` y `Move-HubProjectsIa.Tests.ps1`.

## Cobertura por fase

| Área | Evidencia |
|------|-----------|
| Perfiles ×4 | characterization + equivalence goldens |
| Full ≡ ConsultingAI | equivalence + Full.Tests |
| Registry v2 | HubRegistry.Tests + piloto |
| Diagnósticos read-only | Entrypoints.Tests + piloto sentinels |
| Launcher Bash | HubLauncher.Tests + shellcheck |
| Move Windows-only | Move-HubProjectsIa.Tests (fail-fast Linux) |
| Piloto real WSL | docs/PILOT-HUB-MULTIPLATFORM.md |

## Nota Windows nativo

La suite Pester no se ejecutó en este cierre sobre Windows nativo. La paridad de artefactos se valida con manifiestos normalizados (`tests/equivalence`). Repetir `Run-Tests.ps1` y `Invoke-HubPilot.ps1` en Windows cuando haya host disponible.
