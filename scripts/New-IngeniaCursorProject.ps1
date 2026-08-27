#Requires -Version 5.1
<#
.SYNOPSIS
  Alias retrocompatible — delega en New-IngeniaTemplateProject.ps1 (ConsultingAI).

.DESCRIPTION
  Cadena de aliases:
    New-IngeniaCursorProject.ps1
      → New-IngeniaTemplateProject.ps1
        → New-ConsultingCopilotProject.ps1 -StackProfile ConsultingAI

  Preferí New-HubProject.ps1 para proyectos bajo el hub.

.EXAMPLE
  # Windows
  pwsh -File .\New-IngeniaCursorProject.ps1 -TargetPath "D:\work\proyecto" -ClientSlug "acme" -InitiativeId "U01" -ClientDisplayName "ACME" -InitiativeDisplayName "Ini"

.EXAMPLE
  # Ubuntu/WSL
  pwsh -File ./New-IngeniaCursorProject.ps1 -TargetPath "/home/user/work/proyecto" -ClientSlug "acme" -InitiativeId "U01" -ClientDisplayName "ACME" -InitiativeDisplayName "Ini"
#>
$main = Join-Path $PSScriptRoot 'New-IngeniaTemplateProject.ps1'
if (-not (Test-Path -LiteralPath $main)) {
  throw "No se encuentra: $main"
}
& $main @args
