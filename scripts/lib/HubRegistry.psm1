#Requires -Version 7.0
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Platform.psm1') -Force

$script:HubRegistryCurrentSchemaVersion = 2

function ConvertFrom-HubRegistryJsonValue {
  param($Node)
  if ($null -eq $Node) { return $null }
  if ($Node -is [System.Text.Json.Nodes.JsonObject]) {
    $map = [ordered]@{}
    foreach ($prop in $Node.AsObject()) {
      $map[$prop.Key] = ConvertFrom-HubRegistryJsonValue -Node $prop.Value
    }
    return [pscustomobject]$map
  }
  if ($Node -is [System.Text.Json.Nodes.JsonArray]) {
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Node.AsArray()) {
      $list.Add((ConvertFrom-HubRegistryJsonValue -Node $item)) | Out-Null
    }
    return @($list)
  }
  $kind = $Node.GetValueKind()
  switch ($kind) {
    'String' {
      return [System.Text.Json.JsonSerializer]::Deserialize($Node.ToJsonString(), [string])
    }
    'Number' {
      $asLong = 0L
      if ([long]::TryParse($Node.ToString(), [ref]$asLong)) { return $asLong }
      return [double]::Parse($Node.ToString(), [System.Globalization.CultureInfo]::InvariantCulture)
    }
    'True' { return $true }
    'False' { return $false }
    'Null' { return $null }
    default { return $Node.ToString() }
  }
}

function ConvertFrom-HubRegistryJsonText {
  param([Parameter(Mandatory = $true)][string] $JsonText)
  $node = [System.Text.Json.Nodes.JsonNode]::Parse($JsonText)
  return ConvertFrom-HubRegistryJsonValue -Node $node
}

function Get-HubRegistryPath {
  param([Parameter(Mandatory = $true)][string] $HubRoot)
  return Join-HubPath (Resolve-HubRootPath $HubRoot) 'hub-registry.json'
}

function ConvertTo-HubRelativePathLiteral {
  param([Parameter(Mandatory = $true)][string] $Path)
  $normalized = ($Path -replace '\\', '/').Trim()
  while ($normalized.StartsWith('./')) { $normalized = $normalized.Substring(2) }
  return $normalized.Trim('/')
}

function New-HubRegistryDocument {
  param(
    [int] $SchemaVersion = 2,
    [object[]] $Projects = @()
  )
  return [ordered]@{
    schemaVersion = $SchemaVersion
    projects = @($Projects)
  }
}

function ConvertTo-HubRegistryProjectHashtable {
  param([Parameter(Mandatory = $true)] $Project)
  $map = [ordered]@{}
  foreach ($prop in @($Project.PSObject.Properties)) {
    if ($null -eq $prop.Value) { continue }
    if ($prop.Value -is [datetime]) {
      $map[$prop.Name] = ([datetime]$prop.Value).ToString('o')
    } else {
      $map[$prop.Name] = $prop.Value
    }
  }
  return $map
}

function Test-HubRegistryHasPersonalAbsolutePath {
  param([Parameter(Mandatory = $true)][string] $Text)
  if ($Text -match '(?i)^[A-Za-z]:[\\/]') { return $true }
  if ($Text -match '(?i)^/Users/') { return $true }
  if ($Text -match '(?i)^/home/[^/]+/') { return $true }
  if ($Text -match '(?i)^/mnt/[a-z]/') { return $true }
  return $false
}

function Resolve-HubProjectPath {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)] $Project
  )
  $hub = Resolve-HubRootPath $HubRoot
  if ($Project.PSObject.Properties.Name -contains 'relativePath' -and -not [string]::IsNullOrWhiteSpace([string]$Project.relativePath)) {
    $relative = ConvertTo-HubRelativePathLiteral -Path ([string]$Project.relativePath)
    $segments = @($relative -split '/')
    $path = $hub
    foreach ($segment in $segments) {
      if ([string]::IsNullOrWhiteSpace($segment)) { continue }
      $path = Join-Path $path $segment
    }
    return Resolve-HubRootPath $path
  }
  if ($Project.PSObject.Properties.Name -contains 'absolutePath' -and -not [string]::IsNullOrWhiteSpace([string]$Project.absolutePath)) {
    return Resolve-HubRootPath ([string]$Project.absolutePath)
  }
  if ($Project.PSObject.Properties.Name -contains 'folderName' -and -not [string]::IsNullOrWhiteSpace([string]$Project.folderName)) {
    return Resolve-HubRootPath (Join-HubPath $hub 'projects' ([string]$Project.folderName))
  }
  throw "El proyecto del registry no tiene relativePath, absolutePath ni folderName resoluble."
}

function Convert-HubRegistryProjectToV2 {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)] $Project,
    [ValidateSet('Reject', 'KeepExternal')] [string] $ExternalPolicy = 'Reject'
  )

  $hub = Resolve-HubRootPath $HubRoot
  $map = ConvertTo-HubRegistryProjectHashtable -Project $Project
  $folderName = if ($map.Contains('folderName')) { [string]$map['folderName'] } else { $null }

  if ($map.Contains('relativePath') -and -not [string]::IsNullOrWhiteSpace([string]$map['relativePath'])) {
    $map['relativePath'] = ConvertTo-HubRelativePathLiteral -Path ([string]$map['relativePath'])
    if ($map.Contains('absolutePath')) { $map.Remove('absolutePath') }
    if ($map.Contains('absolutePathExternal')) { } # keep if already external marker
    return [pscustomobject]@{
      Project = [pscustomobject]$map
      Converted = $true
      External = ($map.Contains('absolutePathExternal'))
      Warning = $null
    }
  }

  if (-not $map.Contains('absolutePath') -or [string]::IsNullOrWhiteSpace([string]$map['absolutePath'])) {
    if (-not [string]::IsNullOrWhiteSpace($folderName)) {
      $map['relativePath'] = ConvertTo-HubRelativePathLiteral -Path (Join-HubPath 'projects' $folderName)
      return [pscustomobject]@{ Project = [pscustomobject]$map; Converted = $true; External = $false; Warning = $null }
    }
    throw 'Entrada de registry sin absolutePath, relativePath ni folderName.'
  }

  $absolute = Resolve-HubRootPath ([string]$map['absolutePath'])
  if ((Test-HubPathIsChildOf -ChildPath $absolute -ParentPath $hub) -or (Compare-HubPath -Left $absolute -Right $hub)) {
    $suffix = $absolute.Substring($hub.Length).TrimStart('\', '/')
    if ([string]::IsNullOrWhiteSpace($suffix) -and -not [string]::IsNullOrWhiteSpace($folderName)) {
      $suffix = Join-HubPath 'projects' $folderName
    }
    $map['relativePath'] = ConvertTo-HubRelativePathLiteral -Path $suffix
    $map.Remove('absolutePath')
    return [pscustomobject]@{ Project = [pscustomobject]$map; Converted = $true; External = $false; Warning = $null }
  }

  $warning = "Ruta externa al hub ($folderName): $absolute"
  if ($ExternalPolicy -eq 'Reject') {
    throw $warning
  }
  $map['absolutePathExternal'] = $absolute
  if ($map.Contains('absolutePath')) { $map.Remove('absolutePath') }
  if (-not $map.Contains('relativePath') -and -not [string]::IsNullOrWhiteSpace($folderName)) {
    $map['relativePath'] = ConvertTo-HubRelativePathLiteral -Path (Join-HubPath 'projects' $folderName)
  }
  return [pscustomobject]@{
    Project = [pscustomobject]$map
    Converted = $true
    External = $true
    Warning = $warning
  }
}

function Read-HubRegistry {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [string] $RegistryPath
  )
  if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    $RegistryPath = Get-HubRegistryPath -HubRoot $HubRoot
  }
  if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
    return [pscustomobject]@{
      Path = $RegistryPath
      SchemaVersion = 2
      Raw = (New-HubRegistryDocument)
      Projects = @()
      MissingPath = $true
    }
  }

  $rawText = [System.IO.File]::ReadAllText($RegistryPath, [System.Text.UTF8Encoding]::new($false))
  if ([string]::IsNullOrWhiteSpace($rawText)) {
    return [pscustomobject]@{
      Path = $RegistryPath
      SchemaVersion = 2
      Raw = (New-HubRegistryDocument)
      Projects = @()
      MissingPath = $false
    }
  }

  $parsed = ConvertFrom-HubRegistryJsonText -JsonText $rawText
  $schemaVersion = 1
  if ($parsed.PSObject.Properties.Name -contains 'schemaVersion' -and $null -ne $parsed.schemaVersion) {
    $schemaVersion = [int]$parsed.schemaVersion
  }
  $projects = @($parsed.projects)
  $resolved = foreach ($project in $projects) {
    $resolvedPath = $null
    $exists = $false
    $errorMessage = $null
    try {
      $resolvedPath = Resolve-HubProjectPath -HubRoot $HubRoot -Project $project
      $exists = Test-Path -LiteralPath $resolvedPath -PathType Container
    } catch {
      $errorMessage = $_.Exception.Message
    }
    [pscustomobject]@{
      Entry = $project
      FolderName = if ($project.PSObject.Properties.Name -contains 'folderName') { [string]$project.folderName } else { $null }
      RelativePath = if ($project.PSObject.Properties.Name -contains 'relativePath') { [string]$project.relativePath } else { $null }
      AbsolutePath = if ($project.PSObject.Properties.Name -contains 'absolutePath') { [string]$project.absolutePath } else { $null }
      ResolvedPath = $resolvedPath
      Exists = $exists
      ResolveError = $errorMessage
    }
  }

  return [pscustomobject]@{
    Path = $RegistryPath
    SchemaVersion = $schemaVersion
    Raw = $parsed
    Projects = @($resolved)
    MissingPath = $false
  }
}

function ConvertTo-HubRegistryDeterministicJson {
  param([Parameter(Mandatory = $true)] $Document)
  $projectsOut = [System.Collections.Generic.List[object]]::new()
  foreach ($project in @($Document.projects)) {
    $map = ConvertTo-HubRegistryProjectHashtable -Project $project
    # Orden estable de claves conocidas primero.
    $ordered = [ordered]@{}
    foreach ($key in @(
      'folderName', 'relativePath', 'absolutePathExternal', 'stackProfile', 'gitInitialized',
      'createdAt', 'clientSlug', 'initiativeId', 'projectName'
    )) {
      if ($map.Contains($key)) {
        $ordered[$key] = $map[$key]
        $map.Remove($key)
      }
    }
    foreach ($key in @($map.Keys | Sort-Object)) {
      $ordered[$key] = $map[$key]
    }
    $projectsOut.Add([pscustomobject]$ordered) | Out-Null
  }

  $sortedProjects = @($projectsOut | Sort-Object { $_.folderName })
  $out = [ordered]@{
    schemaVersion = [int]$Document.schemaVersion
    projects = $sortedProjects
  }
  return (($out | ConvertTo-Json -Depth 8) + "`n")
}

function Write-HubRegistry {
  param(
    [Parameter(Mandatory = $true)][string] $RegistryPath,
    [Parameter(Mandatory = $true)] $Document
  )
  $json = ConvertTo-HubRegistryDeterministicJson -Document $Document
  $parent = Split-Path -Parent $RegistryPath
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($RegistryPath, $json, [System.Text.UTF8Encoding]::new($false))
  return $RegistryPath
}

function Backup-HubRegistry {
  param(
    [Parameter(Mandatory = $true)][string] $RegistryPath,
    [datetime] $Timestamp = (Get-Date)
  )
  if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
    return $null
  }
  $stamp = $Timestamp.ToString('yyyyMMdd-HHmmss')
  $backupPath = "$RegistryPath.bak-$stamp"
  Copy-Item -LiteralPath $RegistryPath -Destination $backupPath -Force
  return $backupPath
}

function Migrate-HubRegistryToV2 {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [string] $RegistryPath,
    [ValidateSet('Reject', 'KeepExternal')] [string] $ExternalPolicy = 'Reject',
    [switch] $DryRun,
    [switch] $NoBackup
  )

  if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    $RegistryPath = Get-HubRegistryPath -HubRoot $HubRoot
  }
  $current = Read-HubRegistry -HubRoot $HubRoot -RegistryPath $RegistryPath
  $warnings = [System.Collections.Generic.List[string]]::new()
  $convertedProjects = [System.Collections.Generic.List[object]]::new()

  foreach ($item in @($current.Projects)) {
    $result = Convert-HubRegistryProjectToV2 -HubRoot $HubRoot -Project $item.Entry -ExternalPolicy $ExternalPolicy
    $convertedProjects.Add($result.Project) | Out-Null
    if ($result.Warning) { $warnings.Add($result.Warning) | Out-Null }
  }

  $document = New-HubRegistryDocument -SchemaVersion $script:HubRegistryCurrentSchemaVersion -Projects @($convertedProjects)
  $newJson = ConvertTo-HubRegistryDeterministicJson -Document $document
  $oldJson = if (Test-Path -LiteralPath $RegistryPath) {
    [System.IO.File]::ReadAllText($RegistryPath, [System.Text.UTF8Encoding]::new($false))
  } else { '' }

  $changed = ($oldJson -ne $newJson)
  $backupPath = $null
  if ($changed -and -not $DryRun) {
    if (-not $NoBackup -and (Test-Path -LiteralPath $RegistryPath)) {
      $backupPath = Backup-HubRegistry -RegistryPath $RegistryPath
    }
    Write-HubRegistry -RegistryPath $RegistryPath -Document $document | Out-Null
  }

  return [pscustomobject]@{
    Path = $RegistryPath
    SchemaVersion = $script:HubRegistryCurrentSchemaVersion
    Changed = $changed
    DryRun = [bool]$DryRun
    BackupPath = $backupPath
    ProjectCount = $convertedProjects.Count
    Warnings = @($warnings)
    Json = $newJson
  }
}

function Test-HubRegistryPortability {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [string] $RegistryPath
  )
  $current = Read-HubRegistry -HubRoot $HubRoot -RegistryPath $RegistryPath
  $issues = [System.Collections.Generic.List[string]]::new()
  if ($current.SchemaVersion -lt 2) {
    $issues.Add("schemaVersion $($current.SchemaVersion) (se espera 2+)")
  }
  foreach ($item in @($current.Projects)) {
    $entry = $item.Entry
    if ($entry.PSObject.Properties.Name -contains 'absolutePath' -and -not [string]::IsNullOrWhiteSpace([string]$entry.absolutePath)) {
      $issues.Add("absolutePath presente ($($item.FolderName)): $($entry.absolutePath)")
    }
    if ($entry.PSObject.Properties.Name -contains 'relativePath' -and (Test-HubRegistryHasPersonalAbsolutePath -Text ([string]$entry.relativePath))) {
      $issues.Add("relativePath parece absoluta personal ($($item.FolderName)): $($entry.relativePath)")
    }
    if ($item.ResolveError) {
      $issues.Add("No se pudo resolver ($($item.FolderName)): $($item.ResolveError)")
    } elseif (-not $item.Exists) {
      $issues.Add("Proyecto registrado no encontrado ($($item.FolderName)): $($item.ResolvedPath)")
    }
  }
  return [pscustomobject]@{
    Ok = ($issues.Count -eq 0)
    SchemaVersion = $current.SchemaVersion
    Issues = @($issues)
    MissingProjects = @($current.Projects | Where-Object { -not $_.Exists -and -not $_.ResolveError })
  }
}

function Add-HubRegistryProject {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)][hashtable] $Entry,
    [string] $RegistryPath,
    [switch] $Force
  )

  if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    $RegistryPath = Get-HubRegistryPath -HubRoot $HubRoot
  }
  $hub = Resolve-HubRootPath $HubRoot
  $current = Read-HubRegistry -HubRoot $HubRoot -RegistryPath $RegistryPath

  $map = [ordered]@{}
  foreach ($key in @($Entry.Keys)) { $map[$key] = $Entry[$key] }

  if (-not $map.Contains('folderName') -or [string]::IsNullOrWhiteSpace([string]$map['folderName'])) {
    throw 'folderName es obligatorio para registrar un proyecto.'
  }
  if (-not $map.Contains('relativePath') -or [string]::IsNullOrWhiteSpace([string]$map['relativePath'])) {
    if ($map.Contains('absolutePath') -and -not [string]::IsNullOrWhiteSpace([string]$map['absolutePath'])) {
      $converted = Convert-HubRegistryProjectToV2 -HubRoot $hub -Project ([pscustomobject]$map) -ExternalPolicy Reject
      $map = ConvertTo-HubRegistryProjectHashtable -Project $converted.Project
    } else {
      $map['relativePath'] = ConvertTo-HubRelativePathLiteral -Path (Join-HubPath 'projects' ([string]$map['folderName']))
    }
  } else {
    $map['relativePath'] = ConvertTo-HubRelativePathLiteral -Path ([string]$map['relativePath'])
  }
  if ($map.Contains('absolutePath')) { $map.Remove('absolutePath') }

  $projects = [System.Collections.Generic.List[object]]::new()
  foreach ($item in @($current.Projects)) {
    if ($item.FolderName -eq [string]$map['folderName']) {
      if (-not $Force) {
        throw "folderName ya registrado en hub-registry.json: $($map['folderName']). Usá -Force si querés regenerar."
      }
      continue
    }
    $migrated = Convert-HubRegistryProjectToV2 -HubRoot $hub -Project $item.Entry -ExternalPolicy KeepExternal
    $projects.Add($migrated.Project) | Out-Null
  }
  $projects.Add([pscustomobject]$map) | Out-Null

  $document = New-HubRegistryDocument -SchemaVersion $script:HubRegistryCurrentSchemaVersion -Projects @($projects)
  Write-HubRegistry -RegistryPath $RegistryPath -Document $document | Out-Null
  return [pscustomobject]@{
    Path = $RegistryPath
    FolderName = [string]$map['folderName']
    RelativePath = [string]$map['relativePath']
    SchemaVersion = $script:HubRegistryCurrentSchemaVersion
  }
}

Export-ModuleMember -Function @(
  'Get-HubRegistryPath', 'ConvertTo-HubRelativePathLiteral', 'New-HubRegistryDocument',
  'Resolve-HubProjectPath', 'Convert-HubRegistryProjectToV2',
  'Read-HubRegistry', 'ConvertTo-HubRegistryDeterministicJson', 'Write-HubRegistry',
  'Backup-HubRegistry', 'Migrate-HubRegistryToV2', 'Test-HubRegistryPortability',
  'Add-HubRegistryProject', 'Test-HubRegistryHasPersonalAbsolutePath'
)
