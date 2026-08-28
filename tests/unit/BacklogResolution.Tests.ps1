#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:backlogModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'Backlog.psm1'
  $script:copilotModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'ConsultingCopilot.psm1'
  Import-Module $script:backlogModule -Force
}

Describe 'Resolve-BacklogCliStatus' {
  BeforeAll {
    Import-Module $script:backlogModule -Force
  }

  It 'clasifica Missing sin rutas' {
    $s = Resolve-BacklogCliStatus -RawPaths @() -VersionInvoker { $true }
    $s.Status | Should -Be 'Missing'
  }

  It 'reutiliza una instalación nativa válida' {
    Mock Test-HubCommandAllowedOnPlatform { $true } -ModuleName Backlog
    $s = Resolve-BacklogCliStatus -RawPaths @('/usr/local/bin/backlog') -VersionInvoker { $true }
    $s.Status | Should -Be 'Ok'
    $s.Path | Should -Be '/usr/local/bin/backlog'
  }

  It 'rechaza ejecutables Windows en WSL (/mnt/c)' {
    Mock Test-HubCommandAllowedOnPlatform { $false } -ModuleName Backlog
    $s = Resolve-BacklogCliStatus -RawPaths @('/mnt/c/Users/x/AppData/Roaming/npm/backlog.cmd') -VersionInvoker { $true }
    $s.Status | Should -Be 'WindowsOriginRejected'
    $s.RejectedPaths.Count | Should -Be 1
  }

  It 'en WSL prefiere la instalación Linux frente a /mnt/c' {
    Mock Test-HubCommandAllowedOnPlatform {
      param($Name, $Path, $AllowWindowsExecutable)
      return $Path -notmatch '^/mnt/'
    } -ModuleName Backlog
    $s = Resolve-BacklogCliStatus -RawPaths @(
      '/mnt/c/Users/x/AppData/Roaming/npm/backlog.cmd',
      '/home/user/.npm-global/bin/backlog'
    ) -VersionInvoker { $true }
    $s.Status | Should -Be 'Ok'
    $s.Path | Should -Be '/home/user/.npm-global/bin/backlog'
    $s.RejectedPaths | Should -Contain '/mnt/c/Users/x/AppData/Roaming/npm/backlog.cmd'
  }

  It 'marca Invalid si --version falla' {
    Mock Test-HubCommandAllowedOnPlatform { $true } -ModuleName Backlog
    $s = Resolve-BacklogCliStatus -RawPaths @('/usr/local/bin/backlog') -VersionInvoker { $false }
    $s.Status | Should -Be 'Invalid'
  }

  It 'clasifica Duplicate con dos rutas válidas nativas' {
    Mock Test-HubCommandAllowedOnPlatform { $true } -ModuleName Backlog
    $s = Resolve-BacklogCliStatus -RawPaths @('/usr/bin/backlog', '/usr/local/bin/backlog') -VersionInvoker { $true }
    $s.Status | Should -Be 'Duplicate'
  }
}

Describe 'Ensure-BacklogCli' {
  BeforeAll {
    Import-Module $script:backlogModule -Force
  }

  It 'reutiliza sin instalar cuando ya es Ok' {
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'Ok'
        Path = '/usr/local/bin/backlog'
        Paths = @('/usr/local/bin/backlog')
        RejectedPaths = @()
        InvalidPaths = @()
        Message = $null
      }
    } -ModuleName Backlog
    Mock Install-BacklogCli { throw 'no debería instalar' } -ModuleName Backlog

    $r = Ensure-BacklogCli -Mode Auto -Choice I
    $r.Status | Should -Be 'Ok'
    $r.Installed | Should -Be $false
    $r.Path | Should -Be '/usr/local/bin/backlog'
    Should -Invoke Install-BacklogCli -Times 0 -ModuleName Backlog
  }

  It 'instala cuando falta y Choice es I' {
    $script:resolveCalls = 0
    Mock Resolve-BacklogCliStatus {
      $script:resolveCalls++
      if ($script:resolveCalls -eq 1) {
        return [pscustomobject]@{
          Status = 'Missing'; Path = $null; Paths = @(); RejectedPaths = @(); InvalidPaths = @(); Message = 'missing'
        }
      }
      return [pscustomobject]@{
        Status = 'Ok'; Path = '/usr/local/bin/backlog'; Paths = @('/usr/local/bin/backlog')
        RejectedPaths = @(); InvalidPaths = @(); Message = $null
      }
    } -ModuleName Backlog
    Mock Install-BacklogCli { '/usr/local/bin/backlog' } -ModuleName Backlog

    $r = Ensure-BacklogCli -Mode Auto -Choice I
    $r.Status | Should -Be 'Installed'
    $r.Installed | Should -Be $true
    Should -Invoke Install-BacklogCli -Times 1 -ModuleName Backlog
  }

  It 'cancela sin instalar cuando Choice es X' {
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'Missing'; Path = $null; Paths = @(); RejectedPaths = @(); InvalidPaths = @(); Message = 'missing'
      }
    } -ModuleName Backlog
    Mock Install-BacklogCli { throw 'no debería instalar' } -ModuleName Backlog

    $r = Ensure-BacklogCli -Mode Auto -Choice X
    $r.Status | Should -Be 'Cancelled'
    $r.Available | Should -Be $false
    Should -Invoke Install-BacklogCli -Times 0 -ModuleName Backlog
  }

  It 'en modo no interactivo sin Choice falla con mensaje accionable' {
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'Missing'; Path = $null; Paths = @(); RejectedPaths = @(); InvalidPaths = @(); Message = 'missing'
      }
    } -ModuleName Backlog
    {
      Ensure-BacklogCli -Mode Auto
    } | Should -Throw '*BacklogCliChoice*'
  }

  It 'rechaza WindowsOriginRejected sin instalar' {
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'WindowsOriginRejected'
        Path = $null
        Paths = @()
        RejectedPaths = @('/mnt/c/tools/backlog.cmd')
        InvalidPaths = @()
        Message = 'backlog Windows inválido'
      }
    } -ModuleName Backlog
    { Ensure-BacklogCli -Mode Auto -Choice I } | Should -Throw '*Windows*'
  }
}

Describe 'Install-BacklogCli' {
  BeforeAll {
    Import-Module $script:backlogModule -Force
  }

  It 'falla con mensaje accionable si npm no está' {
    Mock Get-HubCommandExecutablePaths {
      param($Name, $AllowWindowsExecutable)
      if ($Name -eq 'node') { return @('/usr/bin/node') }
      if ($Name -eq 'npm') { return @() }
      return @()
    } -ModuleName Backlog

    { Install-BacklogCli } | Should -Throw '*npm*'
  }

  It 'falla si npm install no es cero' {
    Mock Get-HubCommandExecutablePaths {
      param($Name, $AllowWindowsExecutable)
      if ($Name -eq 'node') { return @('/usr/bin/node') }
      if ($Name -eq 'npm') { return @('/usr/bin/npm') }
      return @()
    } -ModuleName Backlog
    Mock Resolve-BacklogNpmPrefixBin { $null } -ModuleName Backlog

    $npmInvoker = {
      param($NpmPath)
      $global:LASTEXITCODE = 1
    }
    { Install-BacklogCli -NpmInvoker $npmInvoker } | Should -Throw '*npm install*'
  }

  It 'falla si tras instalar --version no valida' {
    Mock Get-HubCommandExecutablePaths {
      param($Name, $AllowWindowsExecutable)
      if ($Name -eq 'node') { return @('/usr/bin/node') }
      if ($Name -eq 'npm') { return @('/usr/bin/npm') }
      return @()
    } -ModuleName Backlog
    Mock Resolve-BacklogNpmPrefixBin { $null } -ModuleName Backlog
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'Invalid'
        Path = $null
        Paths = @()
        RejectedPaths = @()
        InvalidPaths = @('/usr/local/bin/backlog')
        Message = 'version failed'
      }
    } -ModuleName Backlog

    $npmInvoker = {
      param($NpmPath)
      $global:LASTEXITCODE = 0
    }
    { Install-BacklogCli -NpmInvoker $npmInvoker -VersionInvoker { $false } } | Should -Throw '*no quedó usable*'
  }

  It 'invoca npm install -g backlog.md@latest --include=optional' {
    $script:npmArgs = $null
    Mock Get-HubCommandExecutablePaths {
      param($Name, $AllowWindowsExecutable)
      if ($Name -eq 'node') { return @('/usr/bin/node') }
      if ($Name -eq 'npm') { return @('/usr/bin/npm') }
      return @()
    } -ModuleName Backlog
    Mock Resolve-BacklogNpmPrefixBin { $null } -ModuleName Backlog
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'Ok'
        Path = '/usr/local/bin/backlog'
        Paths = @('/usr/local/bin/backlog')
        RejectedPaths = @()
        InvalidPaths = @()
        Message = $null
      }
    } -ModuleName Backlog

    $npmInvoker = {
      param($NpmPath, $A1, $A2, $A3, $A4)
      $script:npmArgs = @($A1, $A2, $A3, $A4)
      $global:LASTEXITCODE = 0
    }
    $path = Install-BacklogCli -NpmInvoker $npmInvoker -VersionInvoker { $true }
    $path | Should -Be '/usr/local/bin/backlog'
    ($script:npmArgs -join ' ') | Should -Be 'install -g backlog.md@latest --include=optional'
  }
}

Describe 'ConsultingCopilot Ensure-BacklogCli wrapper' {
  BeforeAll {
    Import-Module $script:copilotModule -Force
  }

  It 'al cancelar no deja pasar y menciona el comando manual' {
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{
        Status = 'Missing'; Path = $null; Paths = @(); RejectedPaths = @(); InvalidPaths = @(); Message = 'missing'
      }
    } -ModuleName Backlog
    {
      Ensure-BacklogCli -Mode Auto -Choice X
    } | Should -Throw '*include=optional*'
  }
}

Describe 'Get-ConsultingMcpServers sin Backlog' {
  BeforeAll {
    Import-Module $script:copilotModule -Force
  }

  It 'no incluye backlog cuando IncludeBacklogMcp es false' {
    $servers = Get-ConsultingMcpServers -IncludeDrawioMcp $true -IncludeBacklogMcp $false -BacklogMcpCwd '/tmp/x' -IncludeArchiMcp $false -ArchiMcpArgs @()
    $servers.Contains('backlog') | Should -Be $false
    $servers.Contains('drawio') | Should -Be $true
  }

  It 'incluye backlog sólo cuando IncludeBacklogMcp es true' {
    $servers = Get-ConsultingMcpServers -IncludeDrawioMcp $false -IncludeBacklogMcp $true -BacklogMcpCwd '/tmp/proj' -IncludeArchiMcp $false -ArchiMcpArgs @()
    $servers['backlog'].command | Should -Be 'backlog'
    $servers['backlog'].args[-1] | Should -Be '/tmp/proj'
  }

  It 'incluye startia con headers env cuando IncludeStartiaMcp es true' {
    $servers = Get-ConsultingMcpServers -IncludeDrawioMcp $false -IncludeBacklogMcp $false -BacklogMcpCwd '' -IncludeArchiMcp $false -ArchiMcpArgs @() -IncludeStartiaMcp $true
    $servers.Contains('startia') | Should -Be $true
    $servers['startia'].url | Should -Be 'https://api.startia.governor.ingenia.la/api/v1/mcp'
    $servers['startia'].headers.Authorization | Should -Be 'Bearer ${env:GOVERNOR_PAT}'
    $servers['startia'].headers.'X-Tenant-Id' | Should -Be '${env:GOVERNOR_TENANT_ID}'
  }

  It 'omite startia cuando IncludeStartiaMcp es false' {
    $servers = Get-ConsultingMcpServers -IncludeDrawioMcp $true -IncludeBacklogMcp $false -BacklogMcpCwd '' -IncludeArchiMcp $false -ArchiMcpArgs @() -IncludeStartiaMcp $false
    $servers.Contains('startia') | Should -Be $false
    $servers.Contains('drawio') | Should -Be $true
  }
}
