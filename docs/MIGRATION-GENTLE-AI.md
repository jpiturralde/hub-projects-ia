# Diagnóstico y migración segura

Los proyectos existentes no se modifican automáticamente.

## Diagnóstico

```powershell
.\scripts\Test-GentleAiProject.ps1 -TargetPath "D:\ruta\proyecto"
gentle-ai doctor
```

Revisar:

- más de un ejecutable en PATH;
- configuración global y workspace simultáneas;
- Engram en `.cursor/mcp.json` local;
- skills locales con el mismo nombre que globales;
- reglas always-on excesivas.

## Principios

1. No borrar ni editar manualmente `gentle-ai.mdc`, agentes, skills, `state.json` o datos de Engram.
2. Previsualizar cualquier operación soportada con `gentle-ai install ... --dry-run`.
3. Usar comandos administrados documentados por la versión instalada.
4. Después de actualizar el binario, ejecutar `gentle-ai sync`.
5. Volver a ejecutar diagnóstico antes de portar cambios del skeleton.

El script informa conflictos pero no decide qué instalación conservar ni ejecuta migraciones.

