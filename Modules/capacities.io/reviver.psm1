# reviver.psm1
# Windows PowerShell 5.1-safe (StrictMode-friendly)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region helpers

function Get-FileTextUtf8 {
  param([Parameter(Mandatory = $true)][string]$Path)
  Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Normalize-AliasPath {
  param([Parameter(Mandatory = $true)][string]$Alias)

  $p = $Alias.Trim()

  # trim leading ./ or .\
  $p = $p -replace '^[.][/\\]+', ''

  # normalize slashes to OS separator
  $p = $p -replace '[/\\]+', [IO.Path]::DirectorySeparatorChar

  return $p
}

function Get-FirstFencedCodeBlock {
  [CmdletBinding()]
  param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Body
  )

  if ([string]::IsNullOrEmpty($Body)) { return $null }

  $opts = [Text.RegularExpressions.RegexOptions]::Singleline
  $pattern = '```[^\r\n]*\r?\n([\s\S]*?)\r?\n```'

  $m = [regex]::Match($Body, $pattern, $opts)
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Parse-CapacitiesPage {
  param([Parameter(Mandatory = $true)][string]$Text)

  # Returns:
  # @{ Aliases=<string[]|null>; Title=<string|null>; Body=<string>; HasFrontMatter=<bool> }
  $result = @{
    Aliases        = $null
    Title          = $null
    Body           = $Text
    HasFrontMatter = $false
  }

  if ($Text -notmatch '^\s*---\s*\r?\n') {
    return $result
  }

  $opts = [Text.RegularExpressions.RegexOptions]::Singleline
  $m = [regex]::Match($Text, '^\s*---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n', $opts)
  if (-not $m.Success) { return $result }

  $fm = $m.Groups[1].Value
  $bodyStart = $m.Length
  $body = $Text.Substring($bodyStart)

  $result.HasFrontMatter = $true
  $result.Body = $body.TrimStart()

  $aliases = New-Object System.Collections.Generic.List[string]
  $inAliasesList = $false

  foreach ($line in ($fm -split "\r?\n")) {
    # title: ...
    if ($line -match '^\s*title:\s*(.+?)\s*$') {
      $t = $Matches[1].Trim()
      if (($t.StartsWith("'") -and $t.EndsWith("'")) -or ($t.StartsWith('"') -and $t.EndsWith('"'))) {
        $t = $t.Substring(1, $t.Length - 2)
      }
      if ($t -and $t -ne 'null') { $result.Title = $t }
      $inAliasesList = $false
      continue
    }

    # aliases: something  (scalar)
    if ($line -match '^\s*aliases:\s*(.*?)\s*$') {
      $inAliasesList = $true
      $a = $Matches[1].Trim()

      if ($a -and $a -ne 'null' -and $a -ne '[]') {
        if (($a.StartsWith("'") -and $a.EndsWith("'")) -or ($a.StartsWith('"') -and $a.EndsWith('"'))) {
          $a = $a.Substring(1, $a.Length - 2)
        }
        $aliases.Add($a) | Out-Null
        $inAliasesList = $false
      }
      continue
    }

    # aliases list items:
    if ($inAliasesList -and ($line -match '^\s*-\s*(.+?)\s*$')) {
      $a2 = $Matches[1].Trim()
      if (($a2.StartsWith("'") -and $a2.EndsWith("'")) -or ($a2.StartsWith('"') -and $a2.EndsWith('"'))) {
        $a2 = $a2.Substring(1, $a2.Length - 2)
      }
      if ($a2 -and $a2 -ne 'null') { $aliases.Add($a2) | Out-Null }
      continue
    }

    # stop list mode on first non-list yaml key-ish line
    if ($inAliasesList -and ($line -match '^\s*\w+\s*:')) {
      $inAliasesList = $false
    }
  }

  if ($aliases.Count -gt 0) {
    $result.Aliases = @($aliases.ToArray())
  }

  return $result
}

function Infer-RootFolderFromAliases {
  param([Parameter(Mandatory = $true)][string[]]$Aliases)

  $firstSegments = @()
  foreach ($a in $Aliases) {
    if (-not $a) { continue }
    $norm = $a.Trim()
    $norm = $norm -replace '^[.][/\\]+', ''
    $seg = ($norm -split '/')[0]
    if ($seg) { $firstSegments += $seg }
  }

  $uniq = @($firstSegments | Sort-Object -Unique)
  if ($uniq.Count -eq 1) { return $uniq[0] }
  return $null
}

function Resolve-FullPath {
  param([Parameter(Mandatory = $true)][string]$p)
  try { return (Resolve-Path -LiteralPath $p).Path } catch { return $null }
}

function Is-ArchivePath {
  param([Parameter(Mandatory = $true)][string]$p)
  $ext = [IO.Path]::GetExtension($p).ToLowerInvariant()
  return @('.zip', '.rar', '.7z') -contains $ext
}

function Get-7ZipCommand {
  $cmd = Get-Command 7z -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  return $null
}

function Ensure-EmptyDir {
  param(
    [Parameter(Mandatory = $true)][string]$dir,
    [switch]$DryRun
  )
  if ($DryRun) {
    Write-Host "[DRY] Ensure empty dir: $dir"
    return
  }
  if (Test-Path -LiteralPath $dir) {
    Remove-Item -LiteralPath $dir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

function Choose-ExtractedPagesRoot {
  param([Parameter(Mandatory = $true)][string]$ExtractDir)

  # Some archives are:
  #  A) flat .md files at root
  #  B) a single folder that contains the flat .md files
  #
  # Heuristic:
  # - If there are .md files directly under ExtractDir, use ExtractDir.
  # - Else if exactly one top-level directory exists AND it contains .md files (recursively), use that directory.
  # - Else use ExtractDir (and let caller error if no .md exist).

  $topMd = @(
    Get-ChildItem -LiteralPath $ExtractDir -File -Filter '*.md' -ErrorAction SilentlyContinue
  )
  if ($topMd.Count -gt 0) { return $ExtractDir }

  $topDirs = @(
    Get-ChildItem -LiteralPath $ExtractDir -Directory -ErrorAction SilentlyContinue
  )

  if ($topDirs.Count -eq 1) {
    $candidate = $topDirs[0].FullName
    $anyMd = @(
      Get-ChildItem -LiteralPath $candidate -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
    )
    if ($anyMd.Count -gt 0) { return $candidate }
  }

  return $ExtractDir
}

#endregion helpers

function Invoke-CapacitiesRevive {
  <#
    .SYNOPSIS
    Rebuilds a Capacities.io markdown archive into a real file tree using the YAML 'aliases:' path.

    .PARAMETER InputDir
    Directory containing Capacities-exported .md files (flat or nested). Defaults to current directory.

    .PARAMETER OutDir
    Output directory. If omitted, defaults to .\<rootFolder> where rootFolder is inferred from aliases.
    If inference fails, defaults to .\revived

    .PARAMETER Overwrite
    Overwrite existing files in OutDir.

    .PARAMETER DryRun
    Print what would be written without writing.
    #>

  [CmdletBinding()]
  param(
    [string]$InputDir = ".",
    [string]$OutDir,
    [switch]$Overwrite,
    [switch]$DryRun,
    [string]$StripRootPrefix
  )

  $resolvedInput = Resolve-FullPath $InputDir
  if (-not $resolvedInput) { throw "InputDir does not exist: $InputDir" }
  $InputDir = $resolvedInput

  $mdFiles = @(
    Get-ChildItem -LiteralPath $InputDir -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
  )
  if ($mdFiles.Count -eq 0) {
    throw "No .md files found under: $InputDir"
  }

  $pages = @()
  $allAliases = @()

  foreach ($f in $mdFiles) {
    $txt = Get-FileTextUtf8 $f.FullName
    $p = Parse-CapacitiesPage $txt

    if (-not $p.Aliases -or @($p.Aliases).Count -eq 0) { continue }

    # Prefer the first alias as the "true path"
    $aliasRaw = @($p.Aliases)[0]
    if (-not $aliasRaw) { continue }

    $allAliases += $aliasRaw

    $pages += [pscustomobject]@{
      SourcePath = $f.FullName
      AliasRaw   = $aliasRaw
      AliasNorm  = (Normalize-AliasPath $aliasRaw)
      Title      = $p.Title
      Body       = $p.Body
    }
  }

  if (@($pages).Count -eq 0) {
    throw "No pages with an 'aliases:' field were found."
  }

  $stripRoot = $false
  $rootPrefix = $null
  

  if ($StripRootPrefix) {
    $stripRoot = $true
    $rootPrefix = (Normalize-AliasPath ($StripRootPrefix.TrimEnd('/', '\'))) + [IO.Path]::DirectorySeparatorChar
  }
  elseif (-not $PSBoundParameters.ContainsKey('OutDir')) {
    $root = Infer-RootFolderFromAliases $allAliases
    if ($root) {
      
      $OutDir = Join-Path "." $root
      $stripRoot = $true
      $rootPrefix = (Normalize-AliasPath ($root.TrimEnd('/', '\'))) + [IO.Path]::DirectorySeparatorChar
    }
    else {
      $oo = $outDir
      if ($outDir -eq $null ) { $oo = Join-Path '.' 'revived'} else { $oo= $outDir }
      $OutDir = $oo
    }
  }
  elseif (-not $OutDir) {
    $OutDir = Join-Path "." "revived"
  }


  if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  }

  $written = 0
  $dirsMade = 0
  $skipped = 0

  foreach ($page in $pages) {
    $rel = $page.AliasNorm

    if ($stripRoot -and $rootPrefix -and $rel.StartsWith($rootPrefix)) {
      $rel = $rel.Substring($rootPrefix.Length)
    }

    $isDir = $page.AliasRaw.Trim().EndsWith("/")

    $targetPath = Join-Path $OutDir $rel

    if ($isDir) {
      if ($DryRun) {
        Write-Host "[DIR ] $targetPath"
      }
      else {
        New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
      }
      $dirsMade++
      continue
    }

    $targetDir = Split-Path -Parent $targetPath
    if ($targetDir -and -not $DryRun) {
      New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    if ((Test-Path -LiteralPath $targetPath) -and -not $Overwrite) {
      Write-Host "[SKIP] Exists (use -Overwrite): $targetPath"
      $skipped++
      continue
    }

    $bodySafe = $(if ($null -ne $page.Body) { [string]$page.Body } else { "" })
    $code = Get-FirstFencedCodeBlock -Body $bodySafe
    $contentToWrite = $(if ($null -ne $code) { $code } else { $bodySafe })

    if ($DryRun) {
      Write-Host "[FILE] $targetPath  (from: $($page.SourcePath))"
    }
    else {
      $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
      [IO.File]::WriteAllText($targetPath, $contentToWrite, $utf8NoBom)
    }

    $written++
  }

  Write-Host ""
  Write-Host "Output root: $OutDir"
  Write-Host "Directories created: $dirsMade"
  Write-Host "Files written:       $written"
  Write-Host "Files skipped:       $skipped"
  Write-Host ("Dry run:             " + [bool]$DryRun)
}

function Invoke-CapacitiesReviveAuto {
  [CmdletBinding()]
  param(
    [string]$InputDir = ".",
    [string]$OutDir,
    [switch]$Overwrite,
    [switch]$DryRun,
    [bool]$DeleteSource = $true
  )

  $resolved = Resolve-FullPath $InputDir

  # --- Directory mode: return before any archive logic ---
  if ($resolved -and -not (Is-ArchivePath $resolved)) {
    Invoke-CapacitiesRevive -InputDir $resolved -OutDir $OutDir -Overwrite:$Overwrite -DryRun:$DryRun
    return
  }

  # --- Archive mode from here down (ONLY here) ---
  $archivePath = $(if ($resolved) { $resolved } else { $InputDir })
  if (-not (Test-Path -LiteralPath $archivePath)) {
    throw "InputDir not found: $archivePath"
  }
  if (-not (Is-ArchivePath $archivePath)) {
    throw "InputDir is neither a directory nor a supported archive (.zip/.rar/.7z): $archivePath"
  }

  $archiveBaseName = [IO.Path]::GetFileNameWithoutExtension($archivePath)

  if (-not $OutDir) {
    $OutDir = Join-Path (Get-Location).Path $archiveBaseName
  }

  if (-not $DryRun) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }

  $extractDir = Join-Path $OutDir ".cap_extract"
  Ensure-EmptyDir -dir $extractDir -DryRun:$DryRun

  $ext = [IO.Path]::GetExtension($archivePath).ToLowerInvariant()

  if ($DryRun) {
    Write-Host "[DRY] Extract $archivePath -> $extractDir"
  }
  else {
    if ($ext -eq ".zip") {
      Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
    }
    else {
      $sevenZip = Get-7ZipCommand
      if (-not $sevenZip) {
        throw "7-Zip is required to extract $ext archives. Install 7-Zip (7z.exe) or add it to PATH."
      }
      & $sevenZip x "-y" "-o$extractDir" $archivePath | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed with exit code $LASTEXITCODE"
      }
    }
  }

  $pagesRoot = Choose-ExtractedPagesRoot -ExtractDir $extractDir

  Invoke-CapacitiesRevive `
    -InputDir $pagesRoot `
    -OutDir $OutDir `
    -Overwrite:$Overwrite `
    -DryRun:$DryRun `
    -StripRootPrefix $archiveBaseName

  if ($DeleteSource) {
    if ($DryRun) {
      Write-Host "[DRY] Delete extracted staging: $extractDir"
      Write-Host "[DRY] Delete source archive: $archivePath"
    }
    else {
      if (Test-Path -LiteralPath $extractDir) {
        Remove-Item -LiteralPath $extractDir -Recurse -Force
      }
      Remove-Item -LiteralPath $archivePath -Force
    }
  }
  else {
    Write-Host "Kept extracted staging at: $extractDir"
  }

  Write-Host "Done. Output root: $OutDir"
}


Export-ModuleMember -Function Invoke-CapacitiesRevive, Invoke-CapacitiesReviveAuto
