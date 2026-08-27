# Diferencias permitidas entre manifiestos Windows y Ubuntu/WSL
#
# La suite `tests/equivalence` compara contratos normalizados en
# `tests/expected/*/manifest.json`. Esos contratos deben coincidir en ambas
# plataformas tras la normalización.

## Normalizado (no cuenta como diferencia)

| Aspecto | Tratamiento |
|---------|-------------|
| Separadores `\` vs `/` | Rutas relativas canónicas con `/` |
| `generatedAt` / `createdAt` / `installedAt` | Eliminados del JSON antes del fingerprint |
| Rutas absolutas al proyecto | Reemplazadas por `<PROJECT_ROOT>` |
| CRLF vs LF | Normalizado a LF antes del hash |
| BOM UTF-8 | Eliminado |
| `.git/`, `onboarding-pending.json`, `node_modules/` | Excluidos del manifiesto |

## Diferencias de perfil permitidas

| Comparación | Permitido |
|-------------|-----------|
| `Full` vs `ConsultingAI` | Solo `requestedProfile` (`Full` vs `ConsultingAI`) en `.consulting-engagement.json`; el resto del árbol debe ser equivalente |
| Fingerprints intra-plataforma | Dos generaciones con los mismos parámetros deben ser idénticas tras normalizar |

## No permitido

- Distinto `stackProfile` / `engramMcpSource` para el mismo perfil solicitado.
- Engram en MCP local del hijo.
- Placeholders sin resolver (`{{...}}`).
- Archivos de Gentle AI workspace en perfiles Consulting (sin GA) o ausencia de CDD en ConsultingAI/Full.

## Regenerar goldens

```powershell
pwsh -NoProfile -File ./tests/equivalence/Update-ExpectedManifests.ps1
```

Revisar el diff de `tests/expected/` antes de commitear.
