#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $platformModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'Platform.psm1'
  Import-Module $platformModule -Force
}

Describe 'Get-HubPlatformInfo' {
  AfterEach { Reset-HubPlatformCache }

  It 'detecta Linux/WSL cuando WSL_DISTRO_NAME está presente' {
    Reset-HubPlatformCache
    $original = $env:WSL_DISTRO_NAME
    try {
      $env:WSL_DISTRO_NAME = 'Ubuntu'
      Reset-HubPlatformCache
      if (-not $IsLinux) {
        Set-ItResult -Inconclusive -Because 'El entorno no es Linux'
        return
      }
      $info = Get-HubPlatformInfo
      $info.IsWsl | Should -Be $true
      $info.Platform | Should -Be 'Wsl'
    } finally {
      if ($null -eq $original) { Remove-Item Env:WSL_DISTRO_NAME -ErrorAction SilentlyContinue }
      else { $env:WSL_DISTRO_NAME = $original }
      Reset-HubPlatformCache
    }
  }
}

Describe 'Join-HubPath' {
  It 'compone rutas multi-segmento de forma portable' {
    Join-HubPath '/tmp' 'hub' 'projects' 'demo' | Should -Be (Join-Path (Join-Path (Join-Path '/tmp' 'hub') 'projects') 'demo')
  }
}

Describe 'Compare-HubPath' {
  It 'usa comparación sensible a mayúsculas fuera de Windows nativo' {
    $info = Get-HubPlatformInfo
    if ($info.IsWindowsNative) {
      Compare-HubPath '/tmp/A' '/tmp/a' | Should -Be $true
      return
    }
    if ($IsLinux) {
      Compare-HubPath '/tmp/A' '/tmp/a' | Should -Be $false
      return
    }
    Set-ItResult -Inconclusive -Because 'Plataforma no Linux/Windows para esta aserción'
  }
}

Describe 'Test-HubPathUnderWindowsMount' {
  AfterEach { Reset-HubPlatformCache }

  It 'marca rutas bajo /mnt/c en WSL' {
    if (-not $IsLinux) {
      Set-ItResult -Inconclusive -Because 'Requiere entorno Linux/WSL'
      return
    }
    $original = $env:WSL_DISTRO_NAME
    try {
      $env:WSL_DISTRO_NAME = 'Ubuntu'
      Reset-HubPlatformCache
      Test-HubPathUnderWindowsMount -Path '/mnt/c/Users/demo/project' | Should -Be $true
      Test-HubPathUnderWindowsMount -Path '/home/demo/project' | Should -Be $false
    } finally {
      if ($null -eq $original) { Remove-Item Env:WSL_DISTRO_NAME -ErrorAction SilentlyContinue }
      else { $env:WSL_DISTRO_NAME = $original }
      Reset-HubPlatformCache
    }
  }
}

Describe 'Test-HubExecutableIsWindowsOrigin' {
  It 'detecta /mnt/c y .exe' {
    if (-not $IsLinux) {
      Set-ItResult -Inconclusive -Because 'Requiere entorno Linux/WSL'
      return
    }
    Reset-HubPlatformCache
    $original = $env:WSL_DISTRO_NAME
    try {
      $env:WSL_DISTRO_NAME = 'Ubuntu'
      Reset-HubPlatformCache
      Test-HubExecutableIsWindowsOrigin -Path '/mnt/c/Program Files/nodejs/node.exe' | Should -Be $true
      Test-HubExecutableIsWindowsOrigin -Path '/usr/bin/node' | Should -Be $false
    } finally {
      if ($null -eq $original) { Remove-Item Env:WSL_DISTRO_NAME -ErrorAction SilentlyContinue }
      else { $env:WSL_DISTRO_NAME = $original }
      Reset-HubPlatformCache
    }
  }
}

Describe 'Test-HubCommandAllowedOnPlatform' {
  It 'permite cursor.exe desde WSL y rechaza node.exe' {
    if (-not $IsLinux) {
      Set-ItResult -Inconclusive -Because 'Requiere entorno Linux/WSL'
      return
    }
    Reset-HubPlatformCache
    $original = $env:WSL_DISTRO_NAME
    try {
      $env:WSL_DISTRO_NAME = 'Ubuntu'
      Reset-HubPlatformCache
      Test-HubCommandAllowedOnPlatform -Name 'node' -Path '/mnt/c/Program Files/nodejs/node.exe' | Should -Be $false
      Test-HubCommandAllowedOnPlatform -Name 'cursor' -Path '/mnt/c/Program Files/cursor/cursor.exe' -AllowWindowsExecutable | Should -Be $true
    } finally {
      if ($null -eq $original) { Remove-Item Env:WSL_DISTRO_NAME -ErrorAction SilentlyContinue }
      else { $env:WSL_DISTRO_NAME = $original }
      Reset-HubPlatformCache
    }
  }
}

Describe 'Test-HubArchiMcpPath' {
  It 'exige una ruta absoluta existente' {
    $tempFile = New-TemporaryFile
    try {
      Test-HubArchiMcpPath -Path $tempFile.FullName | Should -Be $tempFile.FullName
      { Test-HubArchiMcpPath -Path 'relative/index.js' } | Should -Throw '*absoluta*'
      { Test-HubArchiMcpPath -Path '/tmp/no-existe-archi-mcp.js' } | Should -Throw '*No se encuentra*'
    } finally {
      Remove-Item -LiteralPath $tempFile.FullName -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'Resolve-HubModulePath' {
  It 'resuelve módulos bajo scripts/lib' {
    $path = Resolve-HubModulePath -ScriptRoot (Join-Path $script:repoRoot 'scripts') -ModuleName 'Platform'
    $path | Should -Be (Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'Platform.psm1')
  }
}
