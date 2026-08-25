#Requires -Version 5.1
<#
.SYNOPSIS
  Alias retrocompatible — delega en New-IngeniaTemplateProject.ps1.

.DESCRIPTION
  El script principal se llama New-IngeniaTemplateProject.ps1. Este archivo conserva el nombre antiguo para scripts o documentación que aún lo invoquen.
#>
$main = Join-Path $PSScriptRoot 'New-IngeniaTemplateProject.ps1'
& $main @args
