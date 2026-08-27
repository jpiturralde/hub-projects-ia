#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:hubLauncher = Join-Path $script:repoRoot 'scripts\hub'
}

Describe 'Launcher Bash scripts/hub' {
  It 'existe y es ejecutable' {
    Test-Path -LiteralPath $script:hubLauncher -PathType Leaf | Should -Be $true
    $mode = (Get-Item -LiteralPath $script:hubLauncher).UnixMode
    if ($null -ne $mode) {
      $mode | Should -Match 'x'
    }
  }

  It 'pasa shellcheck sin hallazgos' {
    $shellcheck = Get-Command shellcheck -ErrorAction SilentlyContinue
    if (-not $shellcheck) {
      Set-ItResult -Skipped -Because 'shellcheck no está instalado'
      return
    }
    $p = Start-Process -FilePath 'shellcheck' -ArgumentList @($script:hubLauncher) -Wait -PassThru -NoNewWindow
    $p.ExitCode | Should -Be 0
  }

  It 'muestra ayuda con --help (exit 0)' {
    $p = Start-Process -FilePath 'bash' -ArgumentList @($script:hubLauncher, '--help') `
      -WorkingDirectory $script:repoRoot -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $TestDrive 'help-out.txt') `
      -RedirectStandardError (Join-Path $TestDrive 'help-err.txt')
    $p.ExitCode | Should -Be 0
    (Get-Content (Join-Path $TestDrive 'help-out.txt') -Raw) | Should -Match 'doctor'
  }

  It 'sin argumentos muestra uso y sale 1' {
    $p = Start-Process -FilePath 'bash' -ArgumentList @($script:hubLauncher) `
      -WorkingDirectory $script:repoRoot -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $TestDrive 'usage-out.txt') `
      -RedirectStandardError (Join-Path $TestDrive 'usage-err.txt')
    $p.ExitCode | Should -Be 1
  }

  It 'comando desconocido sale 1' {
    $p = Start-Process -FilePath 'bash' -ArgumentList @($script:hubLauncher, 'nope') `
      -WorkingDirectory $script:repoRoot -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $TestDrive 'bad-out.txt') `
      -RedirectStandardError (Join-Path $TestDrive 'bad-err.txt')
    $p.ExitCode | Should -Be 1
    (Get-Content (Join-Path $TestDrive 'bad-err.txt') -Raw) | Should -Match 'desconocido'
  }

  It 'test sin ruta sale 1' {
    $p = Start-Process -FilePath 'bash' -ArgumentList @($script:hubLauncher, 'test') `
      -WorkingDirectory $script:repoRoot -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $TestDrive 'test-out.txt') `
      -RedirectStandardError (Join-Path $TestDrive 'test-err.txt')
    $p.ExitCode | Should -Be 1
  }

  Context 'HUB_LAUNCHER_TRACE' {
    BeforeAll {
      $env:HUB_LAUNCHER_TRACE = '1'
    }
    AfterAll {
      Remove-Item Env:HUB_LAUNCHER_TRACE -ErrorAction SilentlyContinue
    }

    It 'doctor traduce a Install-ConsultingCopilot.ps1' {
      $out = & bash $script:hubLauncher doctor -StackProfile ConsultingAI 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 0
      $out | Should -Match 'Install-ConsultingCopilot\.ps1'
      $out | Should -Match 'StackProfile'
    }

    It 'new traduce a New-HubProject.ps1' {
      $out = & bash $script:hubLauncher new -StackProfile GentleAi -ProjectName demo 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 0
      $out | Should -Match 'New-HubProject\.ps1'
    }

    It 'test traduce a Test-HubProject.ps1 con -TargetPath absoluto' {
      $out = & bash -c "cd '$($script:repoRoot)' && HUB_LAUNCHER_TRACE=1 ./scripts/hub test projects/iplan-prev-2142 -ExpectedProfile ConsultingAI" 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 0
      $out | Should -Match 'Test-HubProject\.ps1'
      $out | Should -Match '-TargetPath'
      $out | Should -Match 'iplan-prev-2142'
    }

    It 'refresh sin args usa -AllFromRegistry' {
      $out = & bash $script:hubLauncher refresh 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 0
      $out | Should -Match 'Refresh-ProjectGettingStarted\.ps1'
      $out | Should -Match 'AllFromRegistry'
    }

    It 'refresh con ruta usa -TargetPath' {
      $out = & bash -c "cd '$($script:repoRoot)' && HUB_LAUNCHER_TRACE=1 ./scripts/hub refresh projects/iplan-prev-2142" 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 0
      $out | Should -Match 'Refresh-ProjectGettingStarted\.ps1'
      $out | Should -Match '-TargetPath'
    }
  }

  It 'no contiene lógica de negocio prohibida' {
    $src = Get-Content -LiteralPath $script:hubLauncher -Raw
    $src | Should -Not -Match 'hub-registry\.json'
    $src | Should -Not -Match 'gentle-ai install'
    $src | Should -Not -Match 'robocopy'
    $src | Should -Not -Match 'New-Item'
  }
}
